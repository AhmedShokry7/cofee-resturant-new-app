import 'package:admin_app/core/locale/app_locale.dart';

const _westernDigits = '0123456789,.%';
const _arabicDigits = '٠١٢٣٤٥٦٧٨٩٬٫٪';

/// Renders the digits in [value] with the numerals of the active language.
///
/// Arabic uses the Arabic-Indic numerals, while English keeps the Western
/// ones. Separators are converted too so a localised number never mixes
/// numeral styles.
String localizeDigits(String value) {
  if (!AppLocale.instance.isArabic) return value;
  return value.split('').map((character) {
    final index = _westernDigits.indexOf(character);
    return index < 0 ? character : _arabicDigits[index];
  }).join();
}

/// Converts Arabic-Indic numerals and separators back to Western ones so a
/// field accepts `١٢٣` and `١٫٥` exactly like `123` and `1.5`.
String normalizeDigits(String value) {
  return value.split('').map((character) {
    final index = _arabicDigits.indexOf(character);
    return index < 0 ? character : _westernDigits[index];
  }).join();
}

/// Reads a decimal typed in either language's digits.
///
/// `null` means the text was not a number at all, so the caller can refuse it
/// instead of writing a zero it never read — the same rule the catalogue price
/// and the delivery-fee fields already follow.
double? parseLocalizedNumber(String value) =>
    double.tryParse(normalizeDigits(value.trim()));

/// Reads a whole number typed in either language's digits; `null` when the
/// text is blank or not a number.
int? parseLocalizedInt(String value) =>
    int.tryParse(normalizeDigits(value.trim()));
