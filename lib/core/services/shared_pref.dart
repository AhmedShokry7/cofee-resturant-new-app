import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over `SharedPreferences` that never throws.
///
/// Storage is a convenience, not a hard requirement: a device that cannot
/// give us preferences (a failing platform channel, a locked profile, a first
/// launch before the plugin is ready) must still run the app. Every call here
/// degrades to "no value" / "write ignored" instead of propagating, because a
/// thrown exception during startup used to abort the splash handover and leave
/// the app frozen on the splash screen.
///
/// The plugin keeps its own instance cache, so repeated calls cost nothing
/// extra. Nothing is cached here on purpose: a local copy would survive a
/// reset of the underlying store and hand out stale values.
class SharedPref {
  SharedPref._();

  static Future<void> setValue({
    required String key,
    required String value,
  }) async {
    final prefs = await _instance();
    if (prefs == null) return;
    try {
      await prefs.setString(key, value);
    } catch (error) {
      debugPrint('[SharedPref] write failed for "$key": $error');
    }
  }

  static Future<String?> getValue({required String key}) async {
    final prefs = await _instance();
    if (prefs == null) return null;
    try {
      return prefs.getString(key);
    } catch (error) {
      debugPrint('[SharedPref] read failed for "$key": $error');
      return null;
    }
  }

  /// Writes a value and confirms it landed.
  ///
  /// Used for the onboarding/session marker, where the app must know the flag
  /// survived before it navigates away. Returns false when the write could not
  /// be confirmed, so the caller can decide whether to keep the user in place.
  static Future<bool> setValueConfirmed({
    required String key,
    required String value,
  }) async {
    final prefs = await _instance();
    if (prefs == null) return false;
    try {
      await prefs.setString(key, value);
      return prefs.getString(key) == value;
    } catch (error) {
      debugPrint('[SharedPref] write failed for "$key": $error');
      return false;
    }
  }

  /// The preferences instance, or null when the platform refused to give one.
  static Future<SharedPreferences?> _instance() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('[SharedPref] load failed: $error');
      return null;
    }
  }
}
