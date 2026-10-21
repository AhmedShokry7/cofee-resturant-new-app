import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three appearances the admin app can render.
enum AppThemeMode {
  system,
  light,
  dark;

  AppThemeMode get next => switch (this) {
    AppThemeMode.system => AppThemeMode.light,
    AppThemeMode.light => AppThemeMode.dark,
    AppThemeMode.dark => AppThemeMode.system,
  };

  static AppThemeMode fromName(String? name) => switch (name) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };
}

/// Process-wide theme switch for the admin app.
class AppTheme extends ChangeNotifier {
  AppTheme._();

  static final AppTheme instance = AppTheme._();
  static const _preferenceKey = 'admin_theme_mode';

  AppThemeMode _mode = AppThemeMode.system;

  AppThemeMode get mode => _mode;

  ThemeMode get materialThemeMode => switch (_mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  bool get isDark => _mode == AppThemeMode.dark;

  /// Loads the saved appearance, defaulting to the platform setting.
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _mode = AppThemeMode.fromName(preferences.getString(_preferenceKey));
  }

  Future<void> setMode(AppThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, value.name);
  }

  Future<void> cycle() => setMode(_mode.next);

  @visibleForTesting
  void debugSet(AppThemeMode value) {
    _mode = value;
    notifyListeners();
  }
}
