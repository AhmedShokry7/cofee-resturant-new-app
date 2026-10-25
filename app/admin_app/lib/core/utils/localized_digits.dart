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
