import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/addresses_list.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/payment_methods_list.dart';
import 'package:new_coffee/features/coupon/data/coupons_list.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit()
      : super(
          CheckoutState(
            addresses: getAddressesList(),
            selectedAddress: getAddressesList().first,
            paymentMethods: getPaymentMethodsList(),
            selectedPaymentMethod: getPaymentMethodsList().last,
          ),
        );

  void selectAddress(AddressModel address) {
    emit(state.copyWith(selectedAddress: address));
  }

  void addAddress(AddressModel address) {
    emit(
      state.copyWith(
        addresses: [...state.addresses, address],
        selectedAddress: address,
      ),
    );
  }

  void selectPaymentMethod(PaymentMethodModel method) {
    emit(state.copyWith(selectedPaymentMethod: method));
  }

  /// Applies a coupon code (case-insensitive). Returns false when unknown.
  bool applyCoupon(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    CouponModel? found;
    for (final coupon in getCouponsList()) {
      if (coupon.code.toUpperCase() == normalized) {
        found = coupon;
        break;
      }
    }
    if (found == null) return false;
    emit(state.copyWith(appliedCoupon: found));
    return true;
  }

  void removeCoupon() {
    emit(state.copyWith(clearCoupon: true));
  }

  /// Discount percent parsed from the coupon text ("Get 50% OFF" -> 50).
  /// Reads the existing mock strings — no data changes needed.
  static int couponPercent(CouponModel? coupon) {
    if (coupon == null) return 0;
    final match = RegExp(r'(\d+)\s*%').firstMatch(coupon.discount);
    final percent = int.tryParse(match?.group(1) ?? '') ?? 0;
    return percent.clamp(0, 100);
  }

  /// Payable total: subtotal - coupon discount + delivery fee
  /// (never negative).
  double finalTotal(double subtotal) {
    final discount = subtotal * couponPercent(state.appliedCoupon) / 100;
    final total = subtotal - discount + AppConstant.deliveryFee;
    return total < 0 ? 0 : total;
  }

  /// Discount amount alone (for breakdown rows).
  double discountFor(double subtotal) {
    return subtotal * couponPercent(state.appliedCoupon) / 100;
  }

  /// Single source of truth for the payable breakdown.
  CheckoutSummary summary(double subtotal) {
    final discount = discountFor(subtotal);
    final total = subtotal - discount + AppConstant.deliveryFee;
    return CheckoutSummary(
      subtotal: subtotal,
      discount: discount,
      deliveryFee: AppConstant.deliveryFee,
      total: total < 0 ? 0 : total,
    );
  }

  void placeOrder({required List<CartItem> items, required double total}) {
    final number = DateTime.now().millisecondsSinceEpoch % 1000000;
    emit(
      state.copyWith(
        lastOrder: OrderModel(
          id: "#${number.toString().padLeft(6, '0')}",
          date: DateTime.now(),
          items: items,
          total: total,
        ),
      ),
    );
  }
}
