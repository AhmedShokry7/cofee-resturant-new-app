import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'checkout_state.dart';

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this._coupons,
    required AddressRepository addresses,
    required this._paymentMethods,
    required this._deliveryZoneRepository,
    required this._orders,
    this.currentUserIdProvider,
    this.branchId,
  }) : _addresses = addresses,
       super(const CheckoutState()) {
    load();
  }

  final CouponRepository _coupons;
  final AddressRepository _addresses;
  final PaymentMethodRepository _paymentMethods;
  final DeliveryZoneRepository _deliveryZoneRepository;
  final OrdersRepository _orders;
  final String? Function()? currentUserIdProvider;

  /// Branch used for category-scoped coupon validation and delivery zones.
  String? branchId;

  /// Monotonic id of the newest coupon validation.
  ///
  /// Only the newest call may write the applied coupon, so a slow earlier
  /// request can never overwrite a newer answer or resurrect a coupon the cart
  /// has since outgrown.
  int _couponGeneration = 0;

  /// Cart the coupon in state was approved for, and the latest cart reported by
  /// the app. A mismatch means the approval is stale and is dropped.
  String? _appliedCartSignature;
  String? _latestCartSignature;

  /// Retained after an ambiguous network failure so retrying the same purchase
  /// reuses the same server idempotency key. A changed request gets a new key.
  String? _pendingOrderSignature;
  String? _pendingOrderIdempotencyKey;
  String? _loadedAttemptUserId;
  bool _orderSubmissionInProgress = false;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _addresses.listAddresses(),
        _paymentMethods.activeMethods(),
        _coupons.activeCoupons(),
      ]);
      if (isClosed) return;
      final addresses = results[0] as List<AddressModel>;
      final paymentMethods = results[1] as List<PaymentMethodModel>;
      final coupons = results[2] as List<CouponModel>;

      emit(
        state.copyWith(
          addresses: addresses,
          paymentMethods: paymentMethods,
          availableCoupons: coupons,
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
      await _loadDeliveryZones();
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Loads the zones the current branch serves.
  ///
  /// An empty list and a failed load are kept apart: the former means the branch
  /// genuinely serves no zones, the latter (a missing bridge, network or
  /// permission error) means we could not tell. Both fall back to pickup, but
  /// the failure is recorded in the state and logged so it is not silent.
  Future<void> _loadDeliveryZones() async {
    final branch = branchId?.trim() ?? '';
    emit(state.copyWith(deliveryBlocked: false));
    if (branch.isEmpty) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deliveryZones: const [],
          deliveryZonesLoadFailed: false,
          fulfillment: FulfillmentType.pickup,
          clearSelectedDeliveryZone: true,
        ),
      );
      return;
    }
    try {
      final zones = await _deliveryZoneRepository.zonesForBranch(branch);
      if (isClosed) return;
      final hasZones = zones.isNotEmpty;
      emit(
        state.copyWith(
          deliveryZones: zones,
          deliveryZonesLoadFailed: false,
          selectedDeliveryZone: hasZones ? zones.first : null,
          clearSelectedDeliveryZone: !hasZones,
          fulfillment: (!hasZones && state.fulfillment.isDelivery)
              ? FulfillmentType.pickup
              : state.fulfillment,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deliveryZones: const [],
          deliveryZonesLoadFailed: true,
          fulfillment: FulfillmentType.pickup,
          clearSelectedDeliveryZone: true,
        ),
      );
      // Log the non-sensitive category so a missing bridge is distinguishable
      // from "this branch serves no zones". The raw error stays in addError for
      // the app's error observer; no credentials or locations are printed.
      if (kDebugMode) {
        debugPrint('Delivery zones unavailable: $error');
      }
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
    // so a stored approval never silently follows a branch change. The same is
    // true for delivery zones, which are branch-specific.
    if (state.appliedCoupon != null) removeCoupon();
    _loadDeliveryZones();
  }

  /// Switches between pickup and delivery. Delivery is refused when the branch
  /// serves no zone (or the zones could not be loaded), rather than producing an
  /// order the server would reject.
  ///
  /// A refused delivery request is remembered in [CheckoutState.deliveryBlocked]
  /// so the shopper cannot then confirm a pickup order believing they picked
  /// delivery. Returns true only when the selection actually changed.
  bool setFulfillment(FulfillmentType fulfillment) {
    if (state.fulfillment == fulfillment) {
      // Re-selecting pickup clears a pending "delivery unavailable" block so
      // checkout can proceed after the shopper explicitly chooses pickup.
      if (!fulfillment.isDelivery && state.deliveryBlocked) {
        emit(state.copyWith(deliveryBlocked: false, clearOrderError: true));
      }
      return true;
    }
    if (fulfillment.isDelivery && state.deliveryZones.isEmpty) {
      emit(
        state.copyWith(
          deliveryBlocked: true,
          orderError: state.deliveryZonesLoadFailed
              ? S.deliveryUnavailableError
              : S.deliveryUnavailable,
        ),
      );
      return false;
    }
    emit(
      state.copyWith(
        fulfillment: fulfillment,
        deliveryBlocked: false,
        clearOrderError: true,
        selectedDeliveryZone: fulfillment.isDelivery
            ? (state.selectedDeliveryZone ?? state.deliveryZones.first)
            : null,
      ),
    );
    return true;
  }

  void selectDeliveryZone(DeliveryZone zone) {
    emit(
      state.copyWith(
        fulfillment: FulfillmentType.delivery,
        deliveryBlocked: false,
        selectedDeliveryZone: zone,
        clearOrderError: true,
      ),
    );
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

  /// Validates a coupon code against the server for the current [items].
  /// Returns false when the code is unknown, expired, below minimum spend, over
  /// a usage limit or outside the cart's scope.
  ///
  /// The device cart is mirrored to the server cart first, because the server
  /// decides the discount from ITS snapshot of the cart (product/category
  /// scope). The numeric discount then comes from the response, never from a
  /// client recomputation, so the shown figure is the amount that will be
  /// charged.
  Future<bool> applyCoupon(String code, {required List<CartItem> items}) async {
    final normalized = code.trim();
    if (normalized.isEmpty || isClosed) return false;
    final signature = _cartSignature(items);
    final generation = ++_couponGeneration;
    _latestCartSignature = signature;
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    try {
      final branch = branchId?.trim() ?? '';
      if (branch.isEmpty) return false;
      final validated = await _coupons.validateForCart(
        code: normalized,
        subtotal: subtotal,
        branchId: branch,
        lines: _lines(items),
      );
      if (isClosed || generation != _couponGeneration) return false;
      // The cart changed while the server was answering: the approval is for a
      // cart the shopper no longer has, so it is not applied.
      if (_latestCartSignature != signature) return false;
      _appliedCartSignature = signature;
      emit(state.copyWith(appliedCoupon: validated, clearCouponError: true));
      return true;
    } on CouponRejectedException catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(couponError: error.message));
      return false;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(couponError: S.couponCheckFailed));
      addError(error, stackTrace);
      return false;
    }
  }

  /// Reports the current device cart so a coupon approved for a different cart
  /// is dropped instead of shown. Safe to call on every cart emission.
  void onCartChanged(List<CartItem> items) {
    final signature = _cartSignature(items);
    _latestCartSignature = signature;
    if (state.appliedCoupon != null && _appliedCartSignature != signature) {
      removeCoupon();
    }
  }

  void removeCoupon() {
    _appliedCartSignature = null;
    emit(state.copyWith(clearCoupon: true));
  }

  /// Payable total: subtotal - coupon discount + delivery fee
  /// (never negative).
  double finalTotal(double subtotal) {
    final discount = discountFor(subtotal);
    final total = subtotal - discount + state.payableDeliveryFee;
    return total < 0 ? 0 : total;
  }

  /// Discount amount alone (for breakdown rows).
  ///
  /// Only the server's approved amount for the exact [subtotal] is shown. A
  /// different subtotal means the approval no longer describes the cart, so
  /// nothing is shown rather than a client-side recomputation.
  double discountFor(double subtotal) {
    final applied = state.appliedCoupon;
    if (applied == null) return 0;
    if ((applied.subtotal - subtotal).abs() > 0.005) return 0;
    return applied.discount;
  }

  /// Single source of truth for the payable breakdown.
  CheckoutSummary summary(double subtotal) {
    final discount = discountFor(subtotal);
    final total = subtotal - discount + state.payableDeliveryFee;
    return CheckoutSummary(
      subtotal: subtotal,
      discount: discount,
      deliveryFee: state.payableDeliveryFee,
      total: total < 0 ? 0 : total,
    );
  }

  /// Identity of the cart a coupon approval belongs to: the branch plus every
  /// line's product/note/options and quantity. Any difference means a stored
  /// approval was for a different cart.
  String _cartSignature(List<CartItem> items) {
    final buffer = StringBuffer(branchId?.trim() ?? '');
    for (final item in items) {
      buffer
        ..write('|')
        ..write(item.lineId)
        ..write('x')
        ..write(item.quantity);
    }
    return buffer.toString();
  }

  /// Maps device cart lines to the price-free lines the server re-prices.
  List<PlaceOrderLine> _lines(List<CartItem> items) => [
    for (final item in items)
      PlaceOrderLine(
        productId: item.product.id,
        quantity: item.quantity,
        note: item.note,
        optionValueIds: item.optionValueIds,
        bundleId: item.bundleId,
      ),
  ];

  /// Places the order on the server. Returns true only when the server
  /// persisted it; a failure never produces a receipt and never clears the
  /// cart. The device cart is the UI, but the invoice is the server's.
  ///
  /// Delivery requires a zone the branch serves and a saved address; the server
  /// re-validates both and snapshots the address from `customer_addresses`.
  /// Pickup is the default and is priced without a delivery fee.
  Future<bool> placeOrder({required List<CartItem> items}) async {
    if (state.isPlacingOrder || _orderSubmissionInProgress) return false;
    final branch = branchId?.trim() ?? '';
    if (branch.isEmpty) {
      emit(state.copyWith(orderError: 'Select a branch before paying.'));
      return false;
    }
    if (items.isEmpty) {
      emit(state.copyWith(orderError: 'Your cart is empty.'));
      return false;
    }
    // A shopper who asked for delivery but got "unavailable" must explicitly
    // choose pickup before checkout can proceed, so the order is never silently
    // placed as a pickup they did not pick.
    if (state.deliveryBlocked) {
      emit(state.copyWith(orderError: S.deliveryChoosePickup));
      return false;
    }
    final isDelivery = state.fulfillment.isDelivery;
    final selectedZone = state.selectedDeliveryZone;
    if (isDelivery) {
      if (selectedZone == null) {
        emit(state.copyWith(orderError: S.deliveryZoneRequired));
        return false;
      }
      if (state.selectedAddress == null) {
        emit(state.copyWith(orderError: S.deliveryAddressRequired));
        return false;
      }
      final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
      if (subtotal < state.minimumOrderAmount) {
        emit(state.copyWith(orderError: S.deliveryMinimumNotMet));
        return false;
      }
    }

    final requestSignature = _orderRequestSignature(
      branchId: branch,
      items: items,
      fulfillmentType: state.fulfillment.value,
      deliveryZoneId: isDelivery ? selectedZone!.id : null,
      addressId: isDelivery ? state.selectedAddress!.id : null,
      couponCode: state.appliedCoupon?.coupon.code,
    );
    _orderSubmissionInProgress = true;
    emit(
      state.copyWith(
        isPlacingOrder: true,
        clearLastOrder: true,
        clearOrderError: true,
      ),
    );
    try {
      final idempotencyKey = await _orderAttemptFor(requestSignature);
      final placed = await _orders.placeOrder(
        branchId: branch,
        lines: _lines(items),
        idempotencyKey: idempotencyKey,
        fulfillmentType: state.fulfillment.value,
        deliveryZoneId: isDelivery ? selectedZone!.id : null,
        addressId: isDelivery ? state.selectedAddress!.id : null,
        couponCode: state.appliedCoupon?.coupon.code,
      );
      if (isClosed) return false;
      final userId = _currentOrderUserId;
      if (userId != null) {
        await SharedPref.setValue(
          key: _orderAttemptStorageKey(userId),
          value: '',
        );
      }
      _pendingOrderSignature = null;
      _pendingOrderIdempotencyKey = null;
      final address = state.selectedAddress;
      emit(
        state.copyWith(
          isPlacingOrder: false,
          clearOrderError: true,
          lastOrder: OrderModel(
            id: placed.orderNumber.isEmpty
                ? placed.orderId
                : placed.orderNumber,
            date: placed.placedAt,
            items: items,
            total: placed.grandTotal,
            fulfillmentType: state.fulfillment.value,
            deliveryFee: placed.deliveryFee,
            deliveryZoneName: isDelivery ? selectedZone?.name : null,
            deliveryAddress: isDelivery && address != null
                ? '${address.label} - ${address.details}'
                : null,
          ),
        ),
      );
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(state.copyWith(isPlacingOrder: false, orderError: error.toString()));
      addError(error, stackTrace);
      return false;
    } finally {
      _orderSubmissionInProgress = false;
    }
  }

  String? get _currentOrderUserId =>
      currentUserIdProvider?.call() ??
      (SupabaseService.isReady
          ? SupabaseService.client.auth.currentUser?.id
          : null);

  String _orderAttemptStorageKey(String userId) =>
      'pending_order_attempt_$userId';

  Future<String> _orderAttemptFor(String requestSignature) async {
    final userId = _currentOrderUserId;
    if (userId != _loadedAttemptUserId) {
      _pendingOrderSignature = null;
      _pendingOrderIdempotencyKey = null;
    }
    if (userId != null && _loadedAttemptUserId != userId) {
      final stored = await SharedPref.getValue(
        key: _orderAttemptStorageKey(userId),
      );
      _loadedAttemptUserId = userId;
      if (stored != null && stored.isNotEmpty) {
        try {
          final attempt = jsonDecode(stored) as Map<String, dynamic>;
          if (attempt['signature'] == requestSignature &&
              attempt['key'] is String &&
              (attempt['key'] as String).isNotEmpty) {
            _pendingOrderSignature = requestSignature;
            _pendingOrderIdempotencyKey = attempt['key'] as String;
          }
        } on FormatException {
          // A malformed local record is ignored and replaced with a new key.
        } on TypeError {
          // A malformed local record is ignored and replaced with a new key.
        }
      }
    }

    if (_pendingOrderSignature != requestSignature ||
        _pendingOrderIdempotencyKey == null) {
      _pendingOrderSignature = requestSignature;
      _pendingOrderIdempotencyKey = _newOrderIdempotencyKey();
    }
    final key = _pendingOrderIdempotencyKey!;
    if (userId != null) {
      await SharedPref.setValue(
        key: _orderAttemptStorageKey(userId),
        value: jsonEncode({'signature': requestSignature, 'key': key}),
      );
    }
    return key;
  }

  String _orderRequestSignature({
    required String branchId,
    required List<CartItem> items,
    required String fulfillmentType,
    required String? deliveryZoneId,
    required String? addressId,
    required String? couponCode,
  }) {
    final canonical = jsonEncode([
      branchId,
      fulfillmentType,
      deliveryZoneId,
      addressId,
      couponCode?.trim().toUpperCase(),
      for (final item in items)
        [
          item.product.id,
          item.quantity,
          item.note,
          [...item.optionValueIds]..sort(),
          item.bundleId,
        ],
    ]);
    // Persist only a compact fingerprint, not cart notes or address identifiers.
    final mask = BigInt.parse('18446744073709551615');
    final prime = BigInt.parse('1099511628211');
    var hash = BigInt.parse('14695981039346656037');
    for (final unit in canonical.codeUnits) {
      hash = ((hash ^ BigInt.from(unit)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  String _newOrderIdempotencyKey() {
    final random = Random.secure();
    return List<String>.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
      growable: false,
    ).join();
  }
}
