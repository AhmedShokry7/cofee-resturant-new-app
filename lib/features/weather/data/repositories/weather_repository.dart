import 'package:new_coffee/features/weather/data/model/weather_model.dart';

abstract class WeatherRepository {
  Future<WeatherModel> getCurrentWeather();
}
