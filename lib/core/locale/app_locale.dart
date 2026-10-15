import 'package:flutter/widgets.dart';

/// Which language the UI should render.
///
/// Held in one place so a model can expose a locale-aware `name` without every
/// widget having to thread a locale through its constructor. The database
/// stores both languages (decision D4); this decides which one the screen shows.
enum AppLanguage {
  arabic('ar'),
  english('en');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? code) =>
      code == 'en' ? AppLanguage.english : AppLanguage.arabic;

  bool get isArabic => this == AppLanguage.arabic;
}

/// Process-wide language switch.
class AppLocale extends ChangeNotifier {
  AppLocale._();

  static final AppLocale instance = AppLocale._();

  AppLanguage _language = AppLanguage.arabic;

  AppLanguage get language => _language;

  bool get isArabic => _language.isArabic;

  /// Arabic in an RTL layout, English in an LTR one.
  TextDirection get textDirection =>
      _language.isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }

  void toggle() =>
      setLanguage(_language.isArabic ? AppLanguage.english : AppLanguage.arabic);

  @visibleForTesting
  void debugSet(AppLanguage value) {
    _language = value;
    notifyListeners();
  }
}

/// Picks the right value from a bilingual pair, falling back to the other
/// language when one side is missing rather than rendering an empty string.
({T ar, T en}) pickLanguage<T>(
  ({T ar, T en}) pair, {
  required bool isArabic,
  T Function()? fallback,
}) {
  final preferred = isArabic ? pair.ar : pair.en;
  if (preferred is String && preferred.isNotEmpty) return pair;
  final other = isArabic ? pair.en : pair.ar;
  if (other is String && other.isNotEmpty) return pair;
  return fallback != null ? (ar: fallback(), en: fallback()) : pair;
}

/// Resolves a bilingual pair into a plain string.
String pickText(
  ({String ar, String en}) pair, {
  required bool isArabic,
  String fallback = '',
}) {
  if (isArabic && pair.ar.trim().isNotEmpty) return pair.ar;
  if (!isArabic && pair.en.trim().isNotEmpty) return pair.en;
  return isArabic ? pair.en : pair.ar;
}