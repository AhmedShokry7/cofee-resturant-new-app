import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';

class OrderSummaryMetricFormat {
  static String? percent(double current, double previous) {
    if (previous <= 0) return current <= 0 ? _digits('0%') : S.orderTrendNew;
    final amount = ((current - previous).abs() / previous * 100)
        .toStringAsFixed(1);
    return _digits('$amount%');
  }

  /// The grouped amount with no currency word: the card prints the riyal mark
  /// beside it as a `CurrencyIcon`, like every other price in the app.
  static String money(double value) => count(value.round());

  static String count(int value) => _digits(formatCount(value));

  static String digits(String value) => _digits(value);

  static String _digits(String value) => localizeDigits(value);
}
