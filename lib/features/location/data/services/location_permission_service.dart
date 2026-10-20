import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for the OS location permission, once per install.
///
/// Every step is failure-tolerant: a location prompt is a nice-to-have, so a
/// device that cannot read preferences or reach the location service must
/// still let the app continue. Nothing here throws.
class LocationPermissionService {
  LocationPermissionService._();

  static const String _prefKey = 'location_permission_prompted_v1';

  static Future<bool> hasBeenPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKey) ?? false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LocationPermissionService] read failed: $error');
      }
      return false;
    }
  }

  static Future<void> markPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LocationPermissionService] write failed: $error');
      }
    }
  }

  /// Requests the OS location permission on the first launch only.
  /// Never shows a custom in-app dialog; relies on the system prompt.
  static Future<void> requestOnFirstLaunch() async {
    try {
      if (await hasBeenPrompted()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // permanently denied: do nothing; manual settings path exists in picker.
    } catch (error) {
      // Ignore failures; app continues with fallback location.
      if (kDebugMode) {
        debugPrint('[LocationPermissionService] request failed: $error');
      }
    } finally {
      await markPrompted();
    }
  }
}
