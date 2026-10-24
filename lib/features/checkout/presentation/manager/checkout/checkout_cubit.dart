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
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
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
  int _quoteGeneration = 0;
  String? _requestedQuoteSignature;

  /// Refresh the exact cart/zone/coupon quote from the authoritative checkout
  /// transaction. Repeated widget rebuilds with the same inputs do no work.
  Future<void> refreshCheckoutQuote(List<CartItem> items) async {
    final branch = branchId?.trim() ?? '';
    final delivery = state.fulfillment.isDelivery;
    if (branch.isEmpty ||
        items.isEmpty ||
        state.isResolvingZone ||
        (delivery &&
            (state.addressOutOfZone ||
                state.selectedDeliveryZone == null ||
                state.selectedAddress == null))) {
      _requestedQuoteSignature = null;
      if (state.checkoutQuote != null ||
          state.quoteLoading ||
          state.quoteError != null) {
        _quoteGeneration++;
        emit(
          state.copyWith(
            clearCheckoutQuote: true,
            quoteLoading: false,
            clearQuoteError: true,
          ),
        );
      }
      return;
    }
    final signature =
        '${_cartSignature(items)}|${state.fulfillment.value}|'
        '${state.selectedDeliveryZone?.id ?? ''}|${state.selectedAddress?.id ?? ''}|'
        '${state.appliedCoupon?.coupon.code ?? ''}';
    if (_requestedQuoteSignature == signature &&
        (state.quoteLoading ||
            state.checkoutQuote != null ||
            state.quoteError != null)) {
      return;
    }
    _requestedQuoteSignature = signature;
    final generation = ++_quoteGeneration;
    emit(
      state.copyWith(
        clearCheckoutQuote: true,
        quoteLoading: true,
        clearQuoteError: true,
      ),
    );
    try {
      final quote = _orders is CheckoutQuoteRepository
          ? await (_orders as CheckoutQuoteRepository).quoteCheckout(
              branchId: branch,
              lines: _lines(items),
              fulfillmentType: state.fulfillment.value,
              deliveryZoneId: delivery ? state.selectedDeliveryZone!.id : null,
              addressId: delivery ? state.selectedAddress!.id : null,
              couponCode: state.appliedCoupon?.coupon.code,
            )
          : _localPreviewQuote(items);
      if (isClosed || generation != _quoteGeneration) return;
      emit(
        state.copyWith(
          checkoutQuote: quote,
          quoteLoading: false,
          clearQuoteError: true,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _quoteGeneration) return;
      emit(
        state.copyWith(
          clearCheckoutQuote: true,
          quoteLoading: false,
          quoteError: error.toString(),
        ),
      );
      addError(error, stackTrace);
    }
  }

  CheckoutQuote _localPreviewQuote(List<CartItem> items) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final discount = discountFor(subtotal);
    final fee = state.payableDeliveryFee;
    return CheckoutQuote(
      subtotal: subtotal,
      discountTotal: discount,
      deliveryFee: fee,
      taxTotal: 0,
      grandTotal: (subtotal - discount + fee)
          .clamp(0, double.infinity)
          .toDouble(),
      currencyCode: '',
      productDiscountTotal: _productDiscountFor(items),
    );
  }

  /// The product discount of the cart, from the prices the customer sees.
  ///
  /// The server states the figure on the quote; this is the local estimate of
  /// the same thing, used when there is no quote.
  double _productDiscountFor(List<CartItem> items) {
    var total = 0.0;
    for (final item in items) {
      final oldPrice = item.product.oldPrice;
      if (oldPrice == null) continue;
      final effectiveUnit = item.effectiveUnit;
      // A variant carries the option deltas on top of the product price, so
      // the price before the discount of the variant is the price before the
      // discount of the product plus the same deltas.
      final oldUnit = oldPrice + (effectiveUnit - item.product.price);
      if (oldUnit > effectiveUnit) {
        total += (oldUnit - effectiveUnit) * item.quantity;
      }
    }
    return total;
  }

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
          selectedAddress: addresses.isEmpty
              ? null
              : addresses.firstWhere(
                  (address) => address.isDefault,
                  orElse: () => addresses.first,
                ),
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
      // Zones only tell us what the branch serves; which one covers this
      // customer's address is a second question, asked once the address is
      // known.
      await resolveZoneForSelectedAddress();
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
    // Another branch serves different areas, so "outside the zone" is an answer
    // about the previous branch and must not be carried over.
    emit(state.copyWith(addressOutOfZone: false, isResolvingZone: false));
    resolveZoneForSelectedAddress();
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
        // A hand-picked zone overrides the automatic answer, so the out-of-area
        // flag is cleared: the customer has said which zone they mean.
        addressOutOfZone: false,
        selectedDeliveryZone: zone,
        clearOrderError: true,
      ),
    );
  }

  /// Which zone serves the selected address.
  ///
  /// Called whenever the address changes. The answer drives three things: the
  /// fee shown in the summary, whether delivery is offered at all for this
  /// address, and whether the zone dropdown is still needed.
  ///
  /// An address with no coordinates cannot be placed on a map, so it keeps the
  /// manual choice — that is the documented fallback for addresses saved before
  /// the map picker existed, and refusing them would strand those customers.
  Future<void> resolveZoneForSelectedAddress() async {
    final address = state.selectedAddress;
    final latitude = address?.latitude;
    final longitude = address?.longitude;
    final branch = branchId?.trim() ?? '';

    if (address == null || branch.isEmpty) {
      emit(state.copyWith(addressOutOfZone: false, isResolvingZone: false));
      return;
    }
    if (latitude == null || longitude == null) {
      // Addresses saved without coordinates keep the manually selected zone:
      // the customer can still choose delivery, and the branch's configured
      // zones apply.
      emit(state.copyWith(addressOutOfZone: false, isResolvingZone: false));
      return;
    }

    // The branch's configured delivery zones are authoritative. A fixed
    // client-side radius here used to contradict those zones (and could reject
    // a valid address even though the database would accept its order).
    emit(state.copyWith(isResolvingZone: true));
    try {
      final zones = await _deliveryZoneRepository.zonesForPoint(
        branchId: branch,
        latitude: latitude,
        longitude: longitude,
      );
      if (isClosed) return;
      // The address or branch moved on while this was in flight; a newer
      // resolution owns the state.
      if (state.selectedAddress?.id != address.id ||
          branchId?.trim() != branch) {
        return;
      }
      emit(
        state.copyWith(
          isResolvingZone: false,
          addressOutOfZone: zones.isEmpty,
          // Nearest zone wins. `deliveryZones` still holds the full list so a
          // customer outside every zone can pick one by hand if they insist.
          selectedDeliveryZone: zones.isEmpty
              ? null
              : (zones.contains(state.selectedDeliveryZone)
                    ? state.selectedDeliveryZone
                    : zones.first),
          clearSelectedDeliveryZone: zones.isEmpty,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      // We could not tell. Not the same as "out of area", so the previous
      // selection stands and the customer keeps manual choice.
      emit(state.copyWith(isResolvingZone: false, addressOutOfZone: false));
      addError(error, stackTrace);
    }
  }

  /// Chooses which saved card pays for this order.
  ///
  /// Null clears the choice and the hosted card form opens at payment time as
  /// before. Setting a card means the checkout charges it directly, so a
  /// customer who saved a card is never asked to type it again.
  void selectSavedCard(SavedCardModel? card) {
    if (card == null) {
      emit(state.copyWith(clearSelectedSavedCard: true));
      return;
    }
    emit(state.copyWith(selectedSavedCard: card));
  }

  /// Adopts an address list owned by someone else.
  ///
  /// `identity.customer_addresses` is currently mirrored into two cubits: this
  /// one and `AddressesCubit`, both built from the same repository. Nothing told
  /// this cubit when the other one changed, so an address added or made default
  /// in Settings simply never arrived here — the checkout kept the snapshot it
  /// took at construction, and the customer was offered a stale list (or worse,
  /// an address that had since been deleted).
  ///
  /// The same pattern `CartCubit` uses via `onCartChanged`: one writer, the
  /// other side folds the change in rather than keeping its own copy in sync.
  void onAddressesChanged(List<AddressModel> addresses) {
    final currentId = state.selectedAddress?.id;
    // The checkout's selection is not the default flag: the customer may have
    // deliberately picked a different address for this order. So the id is
    // matched, and a default change alone must not move the selection.
    AddressModel? keep;
    for (final address in addresses) {
      if (address.id == currentId) {
        keep = address;
        break;
      }
    }
    // Gone from the list — deleted elsewhere, or the account changed. Fall back
    // to the default rather than keeping an address the server no longer serves.
    final selected = keep ?? _pickInitial(addresses);

    emit(
      state.copyWith(
        addresses: addresses,
        selectedAddress: selected,
        clearSelectedAddress: selected == null,
      ),
    );
    if (selected?.id != currentId) resolveZoneForSelectedAddress();
  }

  /// Prefers the default, else the first — the same choice `load` makes.
  static AddressModel? _pickInitial(List<AddressModel> addresses) {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => addresses.first,
    );
  }

  void selectAddress(AddressModel address) {
    emit(state.copyWith(selectedAddress: address));
    resolveZoneForSelectedAddress();
  }

  Future<void> addAddress(AddressModel address) async {
    try {
      final saved = await _addresses.addAddress(
        label: address.label,
        details: address.details,
        latitude: address.latitude,
        longitude: address.longitude,
        isDefault: state.addresses.isEmpty,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          addresses: [...state.addresses, saved],
          selectedAddress: saved,
        ),
      );
      resolveZoneForSelectedAddress();
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> removeAddress(String id) async {
    try {
      await _addresses.removeAddress(id);
      if (isClosed) return;
      final remaining = state.addresses.where((a) => a.id != id).toList();
      emit(
        state.copyWith(
          addresses: remaining,
          selectedAddress: remaining.isEmpty
              ? null
              : remaining.firstWhere(
                  (address) => address.isDefault,
                  orElse: () => remaining.first,
                ),
          // The last address is gone: the selection must go with it, or the
          // checkout would submit an address the server no longer has.
          clearSelectedAddress: remaining.isEmpty,
        ),
      );
      resolveZoneForSelectedAddress();
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }

  Future<void> setDefaultAddress(String id) async {
    try {
      await _addresses.setDefaultAddress(id);
      if (isClosed) return;
      final updated = state.addresses
          .map((address) => address.copyWith(isDefault: address.id == id))
          .toList();
      emit(state.copyWith(addresses: updated));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }

  /// Clears a consumed error so a later rebuild cannot resurface it.
  ///
  /// The failure was already shown once; keeping it would repeat the same
  /// message on every unrelated rebuild.
  void clearError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  Future<void> updateAddress(AddressModel address) async {
    try {
      final saved = await _addresses.updateAddress(
        id: address.id,
        label: address.label,
        details: address.details,
        latitude: address.latitude,
        longitude: address.longitude,
      );
      if (isClosed) return;
      final updated = state.addresses
          .map((item) => item.id == saved.id ? saved : item)
          .toList();
      emit(state.copyWith(addresses: updated));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(error: error.toString()));
      addError(error, stackTrace);
    }
  }

  void selectPaymentMethod(PaymentMethodModel method) {
    // A saved card can only pay a card method. Keeping the selection while
    // another method is chosen would silently charge the stored card for an
    // Apple Pay or cash order.
    final keepsSavedCard = method.isCardMethod;
    emit(
      state.copyWith(
        selectedPaymentMethod: method,
        clearSelectedSavedCard: !keepsSavedCard,
      ),
    );
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

      // The approval lands first so the discount shows immediately; the
      // per-line explanation follows. Losing it must not lose the discount.
      emit(state.copyWith(appliedCoupon: validated, clearCouponError: true));
      final breakdown = await _coupons.lineBreakdown(
        code: normalized,
        branchId: branch,
        subtotal: subtotal,
        lines: _lines(items),
      );
      if (isClosed || generation != _couponGeneration) return true;
      // Only meaningful while the same coupon is still applied.
      if (state.appliedCoupon?.coupon.code != validated.coupon.code) {
        return true;
      }
      emit(state.copyWith(appliedCoupon: validated.copyWithLines(breakdown)));
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

  /// Display the server quote when available; the fallback supports non-server
  /// previews only and is never allowed to submit a real order.
  double finalTotal(double subtotal) {
    final quote = state.checkoutQuote;
    if (quote != null) return quote.grandTotal;
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
  CheckoutSummary summary(double subtotal, [List<CartItem> items = const []]) {
    final quote = state.checkoutQuote;
    if (quote != null) {
      return CheckoutSummary(
        subtotal: quote.subtotal,
        discount: quote.discountTotal,
        deliveryFee: quote.deliveryFee,
        tax: quote.taxTotal,
        productDiscount: quote.productDiscountTotal,
        total: quote.grandTotal,
      );
    }
    final discount = discountFor(subtotal);
    final total = subtotal - discount + state.payableDeliveryFee;
    return CheckoutSummary(
      subtotal: subtotal,
      discount: discount,
      deliveryFee: state.payableDeliveryFee,
      productDiscount: _productDiscountFor(items),
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
  ///
  /// A bundle is sold as one device line but persists as its component lines,
  /// each carrying the bundle id so the server keeps charging the bundle share.
  List<PlaceOrderLine> _lines(List<CartItem> items) => [
    for (final item in items)
      if (item.isBundle)
        for (final component in item.bundleComponents)
          PlaceOrderLine(
            productId: component.productId,
            quantity: component.quantity * item.quantity,
            note: item.note,
            optionValueIds: item.optionValueIds,
            bundleId: item.bundleId,
          )
      else
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
  Future<bool> placeOrder({
    required List<CartItem> items,
    String? savedCardId,
  }) async {
    if (state.isPlacingOrder || _orderSubmissionInProgress) return false;
    final branch = branchId?.trim() ?? '';
    if (branch.isEmpty) {
      emit(state.copyWith(orderError: S.selectBranchBeforePaying));
      return false;
    }
    if (items.isEmpty) {
      emit(state.copyWith(orderError: S.cartEmpty));
      return false;
    }
    // Order creation requires an authenticated customer. The check depends on
    // the resolved user identity, not on whether Supabase has been initialised,
    // so a guest is rejected in production and in tests alike.
    if (_currentOrderUserId == null) {
      emit(state.copyWith(orderError: S.signIn));
      return false;
    }
    final expectedQuote = state.checkoutQuote;
    final quoteSignature =
        '${_cartSignature(items)}|${state.fulfillment.value}|'
        '${state.selectedDeliveryZone?.id ?? ''}|${state.selectedAddress?.id ?? ''}|'
        '${state.appliedCoupon?.coupon.code ?? ''}';
    if (expectedQuote == null && _orders is CheckoutQuoteRepository ||
        expectedQuote != null && _requestedQuoteSignature != quoteSignature) {
      emit(state.copyWith(orderError: S.orderFailed));
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
      // The address has coordinates and no zone covers it. The server would
      // refuse this too; refusing here means the customer is told before they
      // reach a payment screen.
      if (state.addressOutOfZone) {
        emit(state.copyWith(orderError: S.deliveryOutOfZone));
        return false;
      }
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
      savedCardId: state.selectedSavedCard?.id,
      couponCode: state.appliedCoupon?.coupon.code,
    );
    _orderSubmissionInProgress = true;
    emit(
      state.copyWith(
        isPlacingOrder: true,
        clearLastOrder: true,
        clearOrderError: true,
        clearOrderWarning: true,
      ),
    );
    try {
      final idempotencyKey = await _orderAttemptFor(requestSignature);
      final quoteAware = _orders;
      final orderArgs = (
        branchId: branch,
        lines: _lines(items),
        idempotencyKey: idempotencyKey,
        fulfillmentType: state.fulfillment.value,
        deliveryZoneId: isDelivery ? selectedZone!.id : null,
        addressId: isDelivery ? state.selectedAddress!.id : null,
        couponCode: state.appliedCoupon?.coupon.code,
      );
      final placed = quoteAware is CheckoutQuoteRepository
          ? await (quoteAware as CheckoutQuoteRepository).placeOrderWithQuote(
              branchId: orderArgs.branchId,
              lines: orderArgs.lines,
              idempotencyKey: orderArgs.idempotencyKey,
              expectedTotal: expectedQuote!.grandTotal,
              fulfillmentType: orderArgs.fulfillmentType,
              deliveryZoneId: orderArgs.deliveryZoneId,
              addressId: orderArgs.addressId,
              couponCode: orderArgs.couponCode,
            )
          : await _orders.placeOrder(
              branchId: orderArgs.branchId,
              lines: orderArgs.lines,
              idempotencyKey: orderArgs.idempotencyKey,
              fulfillmentType: orderArgs.fulfillmentType,
              deliveryZoneId: orderArgs.deliveryZoneId,
              addressId: orderArgs.addressId,
              couponCode: orderArgs.couponCode,
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
      final approvedCoupon = state.appliedCoupon;
      emit(
        state.copyWith(
          isPlacingOrder: false,
          clearOrderError: true,
          lastOrder: OrderModel(
            id: placed.orderNumber.isEmpty
                ? placed.orderId
                : placed.orderNumber,
            orderId: placed.orderId,
            date: placed.placedAt,
            items: items,
            total: placed.grandTotal,
            fulfillmentType: state.fulfillment.value,
            deliveryFee: placed.deliveryFee,
            deliveryZoneName: isDelivery ? selectedZone?.name : null,
            deliveryAddress: isDelivery && address != null
                ? '${address.label} - ${address.details}'
                : null,
            discountLines: approvedCoupon?.lines ?? const [],
            productDiscount: placed.productDiscountTotal,
          ),
        ),
      );
      // The server has the last word on the discount. If it granted less than
      // the approval the customer saw (the coupon expired, ran out of uses or
      // no longer fits the cart), the coupon is dropped and the difference is
      // reported: the invoice and the charge both use the server's total, so
      // the customer has to be told that the discount did not apply.
      if (approvedCoupon != null &&
          placed.discountTotal + 0.005 < approvedCoupon.discount) {
        emit(
          state.copyWith(
            clearCoupon: true,
            orderWarning: S.couponNotAppliedAtCheckout,
          ),
        );
      }
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      // Keep diagnostics, but show a customer-facing message rather than a raw
      // backend exception.
      emit(
        state.copyWith(
          isPlacingOrder: false,
          orderError: _customerFacingOrderError(error),
        ),
      );
      addError(error, stackTrace);
      return false;
    } finally {
      _orderSubmissionInProgress = false;
    }
  }

  /// Maps backend/technical failures to a customer-facing message while the
  /// original error is still reported through [addError] for diagnostics.
  String _customerFacingOrderError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('not authenticated') ||
        text.contains('jwt') ||
        text.contains('sign in')) {
      return S.signIn;
    }
    if (text.contains('delivery') || text.contains('zone')) {
      return S.deliveryUnavailable;
    }
    return S.orderFailed;
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
    required String? savedCardId,
    required String? couponCode,
  }) {
    final canonical = jsonEncode([
      branchId,
      fulfillmentType,
      deliveryZoneId,
      addressId,
      savedCardId,
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
