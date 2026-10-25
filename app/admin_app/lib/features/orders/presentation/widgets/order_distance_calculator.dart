import 'dart:math' as math;

class OrderDistanceCalculator {
  static double kilometers(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    final dLat = _radians(lat2 - lat1), dLon = _radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double value) => value * (math.pi / 180);
}
