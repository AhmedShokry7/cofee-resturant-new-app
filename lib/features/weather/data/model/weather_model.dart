class WeatherModel {
  const WeatherModel({required this.temperature});

  final double temperature;

  bool get isHot => temperature >= 25;
}
