import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';

String customerMoney(double value) => localizeDigits(formatAmount(value));

String customerCount(int value) => localizeDigits(formatCount(value));

String customerOrders(int count) =>
    localizeDigits(S.customerOrdersValue(count));

/// Formats [value] percent points, for example `4.8` becomes `٤٫٨٪`.
String customerPercent(double value) => formatPercent(value);

String customerDate(DateTime? value) => localizedDate(value);

String customerLastOrder(DateTime? value) {
  if (value == null) return S.customersNoLastOrder;
  final date = value.toLocal();
  final now = DateTime.now();
  final today = _sameDay(date, now);
  final yesterday = _sameDay(date, now.subtract(const Duration(days: 1)));
  if (!today && !yesterday) return customerDate(date);
  final day = today ? S.today : S.yesterday;
  final separator = AppLocale.instance.isArabic ? '، ' : ', ';
  return localizeDigits('$day$separator${localizedTime(date)}');
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String customerDisplayName(AdminCustomer customer) {
  final name = customer.fullName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  final email = customer.email?.trim() ?? '';
  if (email.isNotEmpty) return email;
  return customer.id;
}

String? customerContactLine(AdminCustomer customer) {
  final name = customerDisplayName(customer);
  final email = customer.email?.trim() ?? '';
  if (email.isNotEmpty && email != name) return email;
  final phone = customer.phone?.trim() ?? '';
  if (phone.isNotEmpty && phone != name) return phone;
  return null;
}

String customerInitials(AdminCustomer customer) =>
    initialsOf(customerDisplayName(customer));
