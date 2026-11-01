import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'main_state.dart';

class MainCubit extends Cubit<MainState> {
  MainCubit() : super(const MainState(index: 0));

  void changeTab(int index) {
    if (index == state.index) return;
    emit(state.withTab(index));
  }
}
