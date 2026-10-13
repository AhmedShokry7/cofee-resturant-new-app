part of 'checkout_cubit.dart';

@immutable
class CheckoutState {
  const CheckoutState({
    required this.addresses,
    required this.selectedAddress,
    required this.paymentMethods,
    required this.selectedPaymentMethod,
    this.lastOrder,
  });

  final List<AddressModel> addresses;
  final AddressModel selectedAddress;
  final List<PaymentMethodModel> paymentMethods;
  final PaymentMethodModel selectedPaymentMethod;
  final OrderModel? lastOrder;

  CheckoutState copyWith({
    List<AddressModel>? addresses,
    AddressModel? selectedAddress,
    List<PaymentMethodModel>? paymentMethods,
    PaymentMethodModel? selectedPaymentMethod,
    OrderModel? lastOrder,
  }) {
    return CheckoutState(
      addresses: addresses ?? this.addresses,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      lastOrder: lastOrder ?? this.lastOrder,
    );
  }
}
