import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/weather/data/model/weather_model.dart';
import 'package:new_coffee/features/weather/data/repositories/weather_repository.dart';

part 'weather_state.dart';

class WeatherCubit extends Cubit<WeatherState> {
  WeatherCubit(this._repository) : super(WeatherInitial());

  final WeatherRepository _repository;

  Future<void> load() async {
    emit(WeatherLoading());
    try {
      final weather = await _repository.getCurrentWeather();
      emit(WeatherLoaded(weather));
    } catch (_) {
      emit(WeatherFailure());
    }
  }
}
