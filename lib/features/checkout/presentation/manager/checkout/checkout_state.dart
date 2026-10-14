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
    required this.addresses,
    required this.selectedAddress,
    required this.paymentMethods,
    required this.selectedPaymentMethod,
    this.lastOrder,
    this.appliedCoupon,
  });

  final List<AddressModel> addresses;
  final AddressModel selectedAddress;
  final List<PaymentMethodModel> paymentMethods;
  final PaymentMethodModel selectedPaymentMethod;
  final OrderModel? lastOrder;

  /// Coupon applied to the current checkout (null = none).
  final CouponModel? appliedCoupon;

  CheckoutState copyWith({
    List<AddressModel>? addresses,
    AddressModel? selectedAddress,
    List<PaymentMethodModel>? paymentMethods,
    PaymentMethodModel? selectedPaymentMethod,
    OrderModel? lastOrder,
    CouponModel? appliedCoupon,
    bool clearCoupon = false,
  }) {
    return CheckoutState(
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      lastOrder: lastOrder ?? this.lastOrder,
      appliedCoupon: clearCoupon ? null : appliedCoupon ?? this.appliedCoupon,
    );
  }
}
