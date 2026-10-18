part of 'checkout_cubit.dart';

/// How the customer receives the order. The database stores the same string
/// (`orders.orders.fulfillment_type`), so the enum keeps one spelling.
enum FulfillmentType {
  pickup('pickup'),
  delivery('delivery');

  const FulfillmentType(this.value);

  final String value;

  bool get isDelivery => this == FulfillmentType.delivery;
}

/// Immutable breakdown of what the customer pays. Computed once in the
/// cubit so cart, checkout and payment pages never disagree.
class CheckoutSummary {
  const CheckoutSummary({
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.total,
  });

  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
}

@immutable
class CheckoutState {
  const CheckoutState({
    this.addresses = const [],
    this.selectedAddress,
    this.paymentMethods = const [],
    this.selectedPaymentMethod,
    this.lastOrder,
    this.appliedCoupon,
    this.availableCoupons = const [],
    this.couponError,
    this.isLoading = true,
    this.isPlacingOrder = false,
    this.orderError,
    this.addressOutOfZone = false,
    this.isResolvingZone = false,
    this.selectedSavedCard,
    this.error,
    this.fulfillment = FulfillmentType.pickup,
    this.deliveryZones = const [],
    this.selectedDeliveryZone,
    this.deliveryZonesLoadFailed = false,
    this.deliveryBlocked = false,
  });

  final List<AddressModel> addresses;
  final AddressModel? selectedAddress;
  final List<PaymentMethodModel> paymentMethods;
  final PaymentMethodModel? selectedPaymentMethod;
  final OrderModel? lastOrder;

  /// Coupon approved for the exact cart subtotal at apply time (null = none).
  ///
  /// The approval carries the server's own discount amount, never a client
  /// recomputation, so a product-scoped coupon shows the same figure the server
  /// will charge. It is dropped as soon as the cart it was approved for changes.
  final ValidatedCoupon? appliedCoupon;

  /// Coupons advertised by the server.
  final List<CouponModel> availableCoupons;

  /// Last coupon validation failure, if any.
  final String? couponError;

  final bool isLoading;

  /// True while a `place_order` call is in flight, so the confirm button can
  /// show progress and cannot be double-submitted.
  final bool isPlacingOrder;

  /// Last placement failure. Never null together with a fresh [lastOrder]:
  /// success clears it before setting [lastOrder].
  final String? orderError;

  final String? error;

  /// Whether the order is collected at the branch or delivered.
  final FulfillmentType fulfillment;

  /// Zones the selected branch serves. Empty means delivery is unavailable.
  final List<DeliveryZone> deliveryZones;

  /// The saved card the customer has chosen to pay with this order.
  ///
  /// Null means "ask for a card at payment time". When set, the checkout charges
  /// it directly instead of opening the hosted card form, so a customer who
  /// saved a card is never asked to type it again.
  final SavedCardModel? selectedSavedCard;

  /// The zone whose fee and minimum apply when [fulfillment] is delivery.
  final DeliveryZone? selectedDeliveryZone;

  /// True when the last attempt to load zones failed: the `delivery_zones_for_
  /// branch` bridge is missing/not deployed, or the request hit a network or
  /// permission error. This is deliberately distinct from an empty
  /// [deliveryZones], which is a valid "this branch serves no zones" answer.
  final bool deliveryZonesLoadFailed;

  /// True when the shopper asked for delivery while it was unavailable and has
  /// not explicitly picked pickup since. [placeOrder] refuses while it is set,
  /// so an attempted delivery can never be silently completed as a pickup.
  final bool deliveryBlocked;

  /// True when the selected address has coordinates and none of the branch's
  /// zones covers it.
  ///
  /// This is the "we do not deliver to your area" answer. It is distinct from
  /// [deliveryBlocked] (delivery was requested but is unavailable at all) and
  /// from [deliveryZonesLoadFailed] (we could not tell) because each one needs a
  /// different message and a different way out.
  final bool addressOutOfZone;

  /// True while a zone lookup for the selected address is in flight, so the UI
  /// does not flash "out of area" before the answer arrives.
  final bool isResolvingZone;

  /// The fee the server will charge for the current selection: the chosen
  /// zone's fee for delivery, and nothing for pickup.
  ///
  /// Read from the zone, which the server priced for this exact address — a
  /// per-km zone carries its own distance-based figure rather than the flat
  /// column value.
  double get payableDeliveryFee =>
      fulfillment.isDelivery ? (selectedDeliveryZone?.deliveryFee ?? 0) : 0;

  /// The minimum order for the current selection, or 0 when none applies.
  double get minimumOrderAmount =>
      fulfillment.isDelivery ? (selectedDeliveryZone?.minOrderAmount ?? 0) : 0;

  CheckoutState copyWith({
    List<AddressModel>? addresses,
    AddressModel? selectedAddress,
    List<PaymentMethodModel>? paymentMethods,
    PaymentMethodModel? selectedPaymentMethod,
    OrderModel? lastOrder,
    bool clearLastOrder = false,
    ValidatedCoupon? appliedCoupon,
    List<CouponModel>? availableCoupons,
    String? couponError,
    bool clearCoupon = false,
    bool clearCouponError = false,
    bool? isLoading,
    bool? isPlacingOrder,
    String? orderError,
    bool clearOrderError = false,
    String? error,
    bool clearError = false,
    FulfillmentType? fulfillment,
    List<DeliveryZone>? deliveryZones,
    DeliveryZone? selectedDeliveryZone,
    bool clearSelectedDeliveryZone = false,
    bool? deliveryZonesLoadFailed,
    bool? deliveryBlocked,
    bool? addressOutOfZone,
    bool? isResolvingZone,
    SavedCardModel? selectedSavedCard,
  }) {
    return CheckoutState(
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      lastOrder: clearLastOrder ? null : lastOrder ?? this.lastOrder,
      appliedCoupon: clearCoupon ? null : appliedCoupon ?? this.appliedCoupon,
      availableCoupons: availableCoupons ?? this.availableCoupons,
      couponError:
          clearCouponError ? null : (couponError ?? this.couponError),
      isLoading: isLoading ?? this.isLoading,
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      orderError: clearOrderError ? null : (orderError ?? this.orderError),
      error: clearError ? null : (error ?? this.error),
      fulfillment: fulfillment ?? this.fulfillment,
      deliveryZones: deliveryZones ?? this.deliveryZones,
      selectedDeliveryZone: clearSelectedDeliveryZone
          ? null
          : selectedDeliveryZone ?? this.selectedDeliveryZone,
      deliveryZonesLoadFailed:
          deliveryZonesLoadFailed ?? this.deliveryZonesLoadFailed,
      deliveryBlocked: deliveryBlocked ?? this.deliveryBlocked,
      addressOutOfZone: addressOutOfZone ?? this.addressOutOfZone,
      selectedSavedCard: selectedSavedCard ?? this.selectedSavedCard,
      isResolvingZone: isResolvingZone ?? this.isResolvingZone,
    );
  }
}
