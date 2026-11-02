import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/motion_tokens.dart';

part 'banner_state.dart';

class BannerCubit extends Cubit<BannerState> {
  BannerCubit({required this.length}) : super(const BannerState(index: 0)) {
    _timer = Timer.periodic(MotionTokens.carouselHold, (_) => next());
  }

  final int length;
  Timer? _timer;

  void next() {
    if (length == 0) return;
    emit(BannerState(index: (state.index + 1) % length));
  }

  /// Moves to a page the customer swiped to.
  ///
  /// Ignored when that page is already the current one: the carousel is read
  /// back through `onPageChanged` after its own animation lands, and emitting a
  /// fresh state there would rebuild the dot row for nothing.
  void jumpTo(int index) {
    if (index == state.index) return;
    emit(BannerState(index: index));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
