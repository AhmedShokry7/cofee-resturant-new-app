import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language the admin UI should render.
///
/// Held in one place so labels and models can expose a locale-aware value
/// without every widget threading a locale through its constructor.
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

/// Process-wide language switch for the admin app.
class AppLocale extends ChangeNotifier {
  AppLocale._();

  static final AppLocale instance = AppLocale._();
  static const _languagePreferenceKey = 'admin_app_language';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  Locale get locale => Locale(_language.code);

  bool get isArabic => _language.isArabic;

  /// Arabic in an RTL layout, English in an LTR one.
  TextDirection get textDirection =>
      _language.isArabic ? TextDirection.rtl : TextDirection.ltr;

  /// Loads the saved language, or follows the device language on first run.
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
