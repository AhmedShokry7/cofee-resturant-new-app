import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';

String orderMoney(double value) => localizeDigits(formatAmount(value));

String orderCount(int value) => localizeDigits(formatCount(value));

String orderUnits(AdminOrder order) => orderCount(
  order.items.fold<int>(0, (total, item) => total + item.quantity),
);

String orderDate(DateTime? value) => localizedDate(value);

String orderDateTime(DateTime? value) => localizedDateTime(value);

String orderPlacedLabel(DateTime? value) => localizedRelativeDay(
  value,
  todayLabel: S.ordersToday,
  yesterdayLabel: S.ordersYesterday,
);

/// The one contact line the directory shows under a customer: the email when
/// the order carries one, otherwise the phone, otherwise nothing.
String? orderContactLine(AdminOrder order) {
  final email = order.customerEmail?.trim() ?? '';
  if (email.isNotEmpty) return email;
  final phone = order.customerPhone?.trim() ?? '';
  return phone.isEmpty ? null : phone;
}
