enum CardBrand {
  visa('VISA'),
  mastercard('MASTERCARD'),
  amex('AMEX'),
  discover('DISCOVER'),
  unknown('');

  const CardBrand(this.label);

  final String label;
}

CardBrand detectCardBrand(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return CardBrand.unknown;

  if (digits.startsWith('4')) return CardBrand.visa;
  if (_isMastercard(digits)) return CardBrand.mastercard;
  if (digits.startsWith('34') || digits.startsWith('37')) return CardBrand.amex;
  if (digits.startsWith('6011') ||
      digits.startsWith('65') ||
      digits.startsWith('64')) {
    return CardBrand.discover;
  }
  return CardBrand.unknown;
}

bool _isMastercard(String digits) {
  if (digits.length < 2) return false;
  final firstTwo = int.tryParse(digits.substring(0, 2)) ?? 0;
  if (firstTwo >= 51 && firstTwo <= 55) return true;
  if (digits.length >= 4) {
    final firstFour = int.tryParse(digits.substring(0, 4)) ?? 0;
    if (firstFour >= 2221 && firstFour <= 2720) return true;
  }
  return false;
}
