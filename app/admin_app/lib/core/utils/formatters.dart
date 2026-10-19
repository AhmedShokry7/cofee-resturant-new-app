String formatMoney(num value, {String currency = 'SAR'}) {
  final fixed = value.toDouble().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = _groupDigits(parts.first);
  final fraction = parts.length > 1 ? parts[1] : '00';
  return '$currency $whole.$fraction';
}

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
