import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/shared/utils/cache_manager.dart';

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
      code?.toLowerCase().split(RegExp('[-_]')).first == 'en'
      ? AppLanguage.english
      : AppLanguage.arabic;

  bool get isArabic => this == AppLanguage.arabic;
}

/// Process-wide language switch.
class AppLocale extends ChangeNotifier {
  AppLocale._();

  static final AppLocale instance = AppLocale._();
  static const _languagePreferenceKey = 'app_language';

  AppLanguage _language = AppLanguage.arabic;

  AppLanguage get language => _language;

  Locale get locale => Locale(_language.code);

  bool get isArabic => _language.isArabic;

  /// Arabic in an RTL layout, English in an LTR one.
  TextDirection get textDirection =>
      _language.isArabic ? TextDirection.rtl : TextDirection.ltr;

  /// Loads the saved app language, or follows the device language on first run.
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage = preferences.getString(_languagePreferenceKey);
    final systemLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _language = AppLanguage.fromCode(savedLanguage ?? systemLanguage);
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languagePreferenceKey, value.code);

    // الأسماء والأوصاف مخزّنة بلغتين وتُعرض حسب اللغة، فكل ما تبقى في الذاكرة
    // بعد تبديلها صار منتهي الصلاحية.
    CacheManager().clear();
  }

  Future<void> toggle() => setLanguage(
    _language.isArabic ? AppLanguage.english : AppLanguage.arabic,
  );

  @visibleForTesting
  void debugSet(AppLanguage value) {
    _language = value;
    notifyListeners();
  }
}

/// Resolves a bilingual pair into a plain string.
String pickText(
  ({String ar, String en}) pair, {
  required bool isArabic,
  String fallback = '',
}) {
  final preferred = isArabic ? pair.ar : pair.en;
  if (preferred.trim().isNotEmpty) return preferred;
  final other = isArabic ? pair.en : pair.ar;
  if (other.trim().isNotEmpty) return other;
  return fallback;
}
