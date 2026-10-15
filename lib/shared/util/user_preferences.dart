import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  UserPreferences._();

  static SharedPreferences? _prefs;

  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme Preferences
  static String get themeMode => _prefs?.getString('theme_mode') ?? 'system';
  static Future setThemeMode(String value) async {
    await _prefs?.setString('theme_mode', value);
  }

  // Layout Preferences
  static double get spacingScale => _prefs?.getDouble('spacing_scale') ?? 1.0;
  static Future setSpacingScale(double value) async {
    await _prefs?.setDouble('spacing_scale', value);
  }

  // Feature Toggles
  static bool get showBanners => _prefs?.getBool('show_banners') ?? true;
  static Future setShowBanners(bool value) async {
    await _prefs?.setBool('show_banners', value);
  }

  static bool get showCategories => _prefs?.getBool('show_categories') ?? true;
  static Future setShowCategories(bool value) async {
    await _prefs?.setBool('show_categories', value);
  }

  // Welcome Screen Preferences
  static String? get welcomeStyle => _prefs?.getString('welcome_style');
  static Future setWelcomeStyle(String value) async {
    await _prefs?.setString('welcome_style', value);
  }

  // Cart Preferences
  static int get maxCartItems => _prefs?.getInt('max_cart_items') ?? 50;
  static Future setMaxCartItems(int value) async {
    await _prefs?.setInt('max_cart_items', value);
  }
}