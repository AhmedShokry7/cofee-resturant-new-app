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

String formatCount(int value) => _groupDigits('$value');

/// Percentage points written with the numerals of the active language, so
/// `4.8` reads `٤٫٨٪` in Arabic. A value within a hair of a whole number
/// drops its fraction, because the metric badge is too narrow for five digits.
String formatPercent(double value) {
  final rounded = value.roundToDouble();
  final text = (value - rounded).abs() < 0.05
      ? rounded.toInt().toString()
      : value.toStringAsFixed(1);
  return localizeDigits('$text%');
}

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
