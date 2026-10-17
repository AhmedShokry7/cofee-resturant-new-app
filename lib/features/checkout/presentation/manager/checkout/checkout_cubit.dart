import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this._coupons,
    required AddressRepository addresses,
    required this._paymentMethods,
    required this._content,
    required this._orders,
    this.branchId,
  }) : _addresses = addresses,
       super(const CheckoutState()) {
    load();
  }

  final CouponRepository _coupons;
  final AddressRepository _addresses;
  final PaymentMethodRepository _paymentMethods;
  final ContentRepository _content;
  final OrdersRepository _orders;

  /// Branch used for category-scoped coupon validation.
  String? branchId;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _addresses.listAddresses(),
        _paymentMethods.activeMethods(),
        _coupons.activeCoupons(),
        _content.deliveryFee(),
      ]);
      if (isClosed) return;
      final addresses = results[0] as List<AddressModel>;
      final paymentMethods = results[1] as List<PaymentMethodModel>;
      final coupons = results[2] as List<CouponModel>;
      final deliveryFee = results[3] as double;

      emit(
        state.copyWith(
          addresses: addresses,
          paymentMethods: paymentMethods,
          availableCoupons: coupons,
          deliveryFee: deliveryFee,
          selectedAddress: addresses.isEmpty ? null : addresses.first,
          selectedPaymentMethod: paymentMethods.isEmpty
              ? null
              : paymentMethods.firstWhere(
                  (method) => method.isOnline,
                  orElse: () => paymentMethods.last,
                ),
          isLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> loadCoupons() async {
    try {
      final coupons = await _coupons.activeCoupons();
      if (isClosed) return;
      emit(state.copyWith(availableCoupons: coupons, clearCouponError: true));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(couponError: error.toString()));
      addError(error, stackTrace);
    }
  }

  void setBranch(String? branchId) {
    if (branchId == this.branchId) return;
    this.branchId = branchId;
    // A category-scoped coupon can become valid or invalid at another branch,
    // so a stored approval never silently follows a branch change.
    if (state.appliedCoupon != null) removeCoupon();
  }

  void selectAddress(AddressModel address) {
    emit(state.copyWith(selectedAddress: address));
  }

  Future<void> addAddress(AddressModel address) async {
    try {
      final saved = await _addresses.addAddress(
        label: address.label,
        details: address.details,
        latitude: address.latitude,
        longitude: address.longitude,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          addresses: [...state.addresses, saved],
          selectedAddress: saved,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> removeAddress(String id) async {
    await _addresses.removeAddress(id);
    if (isClosed) return;
    final remaining = state.addresses.where((a) => a.id != id).toList();
    emit(
      state.copyWith(
        addresses: remaining,
        selectedAddress: remaining.isEmpty ? null : remaining.first,
      ),
    );
  }

  void selectPaymentMethod(PaymentMethodModel method) {
    emit(state.copyWith(selectedPaymentMethod: method));
  }

  /// Validates a coupon code against the server. Returns false when the code
  /// is unknown, expired, below minimum spend, over a usage limit or outside
  /// the cart's scope. The numeric discount comes from the response, never
  /// from display text.
  Future<bool> applyCoupon(String code, {required double subtotal}) async {
    final normalized = code.trim();
    if (normalized.isEmpty || isClosed) return false;
    try {
      final validated = await _coupons.validate(
        code: normalized,
        subtotal: subtotal,
        branchId: branchId,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(appliedCoupon: validated.coupon, clearCouponError: true),
      );
      return true;
    } on CouponRejectedException catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(couponError: error.message));
      return false;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(couponError: error.toString()));
      addError(error, stackTrace);
      return false;
    }
  }

  void removeCoupon() {
    emit(state.copyWith(clearCoupon: true));
  }

  /// Payable total: subtotal - coupon discount + delivery fee
  /// (never negative).
  double finalTotal(double subtotal) {
    final discount = discountFor(subtotal);
    final total = subtotal - discount + state.deliveryFee;
    return total < 0 ? 0 : total;
  }

  /// Discount amount alone (for breakdown rows).
  double discountFor(double subtotal) {
    final coupon = state.appliedCoupon;
    if (coupon == null) return 0;
    return coupon.discountFor(subtotal);
  }

  /// Single source of truth for the payable breakdown.
  CheckoutSummary summary(double subtotal) {
    final discount = discountFor(subtotal);
    final total = subtotal - discount + state.deliveryFee;
    return CheckoutSummary(
      subtotal: subtotal,
      discount: discount,
      deliveryFee: state.deliveryFee,
      total: total < 0 ? 0 : total,
    );
  }

  /// Places the order on the server. Returns true only when the server
  /// persisted it; a failure never produces a receipt and never clears the
  /// cart. The device cart is the UI, but the invoice is the server's.
  ///
  /// Fulfillment is `pickup`: the app has no delivery-zone selection, and the
  /// server rejects a delivery order without a zone the branch actually serves.
  /// The server therefore prices the order without a delivery fee.
  Future<bool> placeOrder({required List<CartItem> items}) async {
    if (state.isPlacingOrder) return false;
    final branch = branchId?.trim() ?? '';
    if (branch.isEmpty) {
      emit(state.copyWith(orderError: 'Select a branch before paying.'));
      return false;
    }
    if (items.isEmpty) {
      emit(state.copyWith(orderError: 'Your cart is empty.'));
      return false;
    }

    emit(
      state.copyWith(
        isPlacingOrder: true,
        clearLastOrder: true,
        clearOrderError: true,
      ),
    );
    try {
      final placed = await _orders.placeOrder(
        branchId: branch,
        lines: [
          for (final item in items)
            PlaceOrderLine(
              productId: item.product.id,
              quantity: item.quantity,
              note: item.note,
              optionValueIds: item.optionValueIds,
              bundleId: item.bundleId,
            ),
        ],
        fulfillmentType: 'pickup',
        couponCode: state.appliedCoupon?.code,
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPlacingOrder: false,
          clearOrderError: true,
          lastOrder: OrderModel(
            id: placed.orderNumber.isEmpty ? placed.orderId : placed.orderNumber,
            date: placed.placedAt,
            items: items,
            total: placed.grandTotal,
          ),
        ),
      );
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isPlacingOrder: false,
          orderError: error.toString(),
        ),
      );
      addError(error, stackTrace);
      return false;
    }
  }
}
