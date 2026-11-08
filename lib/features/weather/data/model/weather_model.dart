class WeatherModel {
  const WeatherModel({
    required this.temperature,
    this.apparentTemperature,
    this.precipitationMm,
    this.weatherCode,
  });

  final double temperature;
  final double? apparentTemperature;
  final double? precipitationMm;
  final int? weatherCode;

  bool get isHot => temperature >= 25;
}
