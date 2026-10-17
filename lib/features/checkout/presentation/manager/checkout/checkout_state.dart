part of 'checkout_cubit.dart';

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
    this.error,
    this.deliveryFee = 20,
  });

  final List<AddressModel> addresses;
  final AddressModel? selectedAddress;
  final List<PaymentMethodModel> paymentMethods;
  final PaymentMethodModel? selectedPaymentMethod;
  final OrderModel? lastOrder;

  /// Coupon applied to the current checkout (null = none).
  final CouponModel? appliedCoupon;

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

  /// Delivery fee from the database, falling back to 20 when unavailable.
  final double deliveryFee;

  CheckoutState copyWith({
    List<AddressModel>? addresses,
    AddressModel? selectedAddress,
    List<PaymentMethodModel>? paymentMethods,
    PaymentMethodModel? selectedPaymentMethod,
    OrderModel? lastOrder,
    bool clearLastOrder = false,
    CouponModel? appliedCoupon,
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
    double? deliveryFee,
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
      deliveryFee: deliveryFee ?? this.deliveryFee,
    );
  }
}
