// Non-web stub — Geolocation API is not available on native platforms here;
// geolocator package handles it directly instead.

class LatLngResult {
  const LatLngResult({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

Future<LatLngResult?> getWebCurrentPosition() async => null;
