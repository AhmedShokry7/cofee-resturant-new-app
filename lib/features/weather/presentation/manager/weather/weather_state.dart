part of 'weather_cubit.dart';

@immutable
sealed class WeatherState {}

final class WeatherInitial extends WeatherState {}

final class WeatherLoading extends WeatherState {}

final class WeatherLoaded extends WeatherState {
  final WeatherModel weather;
  WeatherLoaded(this.weather);
}

final class WeatherFailure extends WeatherState {}
