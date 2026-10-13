import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';

List<PaymentMethodModel> getPaymentMethodsList() {
  return const [
    PaymentMethodModel(
      id: "paypal",
      label: "Paypal",
      icon: HugeIcons.strokeRoundedPaypal,
    ),
    PaymentMethodModel(
      id: "apple_pay",
      label: "Apple Pay",
      icon: HugeIcons.strokeRoundedApple,
    ),
    PaymentMethodModel(
      id: "google_pay",
      label: "Google Pay",
      icon: HugeIcons.strokeRoundedGoogle,
    ),
    PaymentMethodModel(
      id: "on_delivery",
      label: "On Delivery",
      icon: HugeIcons.strokeRoundedTruckDelivery,
    ),
  ];
}
