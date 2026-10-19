import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static const String _prefKey = 'location_permission_prompted_v1';

  static Future<bool> hasBeenPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> markPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Requests the OS location permission on the first launch only.
  /// Never shows a custom in-app dialog; relies on the system prompt.
  static Future<void> requestOnFirstLaunch() async {
    if (await hasBeenPrompted()) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // permanently denied: do nothing; manual settings path exists in picker.
    } catch (_) {
      // Ignore failures; app continues with fallback location.
    } finally {
      await markPrompted();
    }
  }
}
