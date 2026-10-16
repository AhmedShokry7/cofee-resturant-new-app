import 'package:new_coffee/core/locale/app_locale.dart';

class Formatters {
  Formatters._();

  /// Price in the brand currency (SAR). Never a foreign symbol: the catalogue
  /// prices in this app are Saudi riyals, so rendering `$` would charge the
  /// customer in the wrong currency at a glance.
  static String price(double value, [String currencyCode = 'SAR']) {
    final amount = value.toStringAsFixed(2);
    if (AppLocale.instance.isArabic) return '$amount ر.س';
    if (currencyCode.trim().isEmpty || currencyCode == 'SAR') {
      return '$amount SAR';
    }
    return '$amount ${currencyCode.trim()}';
  }

  /// Bare monetary amount (`25.00`) without any currency code or symbol.
  /// Pair with [CurrencyIcon] (see `PriceLabel`) for visual price displays;
  /// [price] stays the text form for prose, slider labels and messages.
  static String amount(double value) => value.toStringAsFixed(2);

  static String date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return "$day/$month/${value.year}";
  }
}
