import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';

/// The order number of the payment, or its own id while the order is unknown.
String paymentOrderLabel(AdminPayment payment) {
  final number = payment.orderNumber?.trim();
  return number == null || number.isEmpty ? payment.id : number;
}

/// The amount of the payment as a number; the currency mark sits beside it.
String paymentMoney(AdminPayment payment) =>
    localizeDigits(formatAmount(payment.amount));

/// The masked card of the payment, such as `Visa •••• 4242`.
String? paymentCardLabel(AdminPayment payment) {
  final brand = payment.cardBrand?.trim() ?? '';
  final last4 = payment.cardLast4?.trim() ?? '';
  if (last4.isEmpty) return brand.isEmpty ? null : brand;
  return brand.isEmpty ? '•••• $last4' : '$brand •••• $last4';
}
