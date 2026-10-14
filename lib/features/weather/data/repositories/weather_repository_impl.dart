import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  const WeatherRepositoryImpl();

  static const double _fallbackLatitude = 16.8892;
  static const double _fallbackLongitude = 42.5511;

  @override
  Future<WeatherModel> getCurrentWeather() async {
    final (latitude, longitude) = await _position();

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude&current=temperature_2m',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Weather request failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final temperature = (current['temperature_2m'] as num).toDouble();
    return WeatherModel(temperature: temperature);
  }

  Future<(double, double)> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (_fallbackLatitude, _fallbackLongitude);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (_fallbackLatitude, _fallbackLongitude);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      return (position.latitude, position.longitude);
    } catch (_) {
      return (_fallbackLatitude, _fallbackLongitude);
    }
  }
}
