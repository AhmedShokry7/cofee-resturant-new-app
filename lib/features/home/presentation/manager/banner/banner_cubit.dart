import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'banner_state.dart';

class BannerCubit extends Cubit<BannerState> {
  BannerCubit({required this.length}) : super(const BannerState(index: 0)) {
    _timer = Timer.periodic(_interval, (_) => next());
  }

  static const Duration _interval = Duration(seconds: 5);

  final int length;
  Timer? _timer;

  void next() {
    if (length == 0) return;
    emit(BannerState(index: (state.index + 1) % length));
  }

  void jumpTo(int index) => emit(BannerState(index: index));

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
