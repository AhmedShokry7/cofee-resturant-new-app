import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

/// A price without the currency prefix.
///
/// The card shows the currency with its own mark, so the amount travels
/// without a currency code attached to it.
String formatAmount(num value) {
  final fixed = value.toDouble().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = _groupDigits(parts.first);
  final fraction = parts.length > 1 ? parts[1] : '00';
  return '$whole.$fraction';
}

/// A price followed by the currency of the active language.
String formatMoneyWithCurrency(num value) =>
    '${localizeDigits(formatAmount(value))} ${S.currency}';

String formatCount(int value) => _groupDigits('$value');

String formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final date = '${local.year}-${_two(local.month)}-${_two(local.day)}';
  final time = '${_two(local.hour)}:${_two(local.minute)}';
  return '$date $time';
}

String _groupDigits(String digits) {
  final negative = digits.startsWith('-');
  final body = negative ? digits.substring(1) : digits;
  final buffer = StringBuffer();
  for (var i = 0; i < body.length; i++) {
    if (i > 0 && (body.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(body[i]);
  }
  return negative ? '-${buffer.toString()}' : buffer.toString();
}

String _two(int value) => value.toString().padLeft(2, '0');
