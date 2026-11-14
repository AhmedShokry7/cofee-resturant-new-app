// Web implementation: uses browser Geolocation API via dart:js_interop.
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// يطلب الموقع عبر Geolocation API للمتصفح.
/// يعيد [LatLngResult] أو null عند الرفض أو عدم الدعم.
Future<LatLngResult?> getWebCurrentPosition() async {
  final completer = Completer<LatLngResult?>();

  web.window.navigator.geolocation.getCurrentPosition(
    (web.GeolocationPosition pos) {
      completer.complete(
        LatLngResult(
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
        ),
      );
    }.toJS,
    (web.GeolocationPositionError err) {
      completer.complete(null);
    }.toJS,
  );

  return completer.future;
}

class LatLngResult {
  const LatLngResult({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}
