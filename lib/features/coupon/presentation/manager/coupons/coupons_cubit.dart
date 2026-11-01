import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';

import 'coupons_state.dart';

/// The coupons the customer may claim right now.
///
/// The page used to hold the `Future` itself, so a rebuild of a parent could
/// re-issue the query and the only way to read the list again after a failure
/// was to leave the screen and come back.
class CouponsCubit extends Cubit<CouponsState> {
  CouponsCubit({required this.repository}) : super(const CouponsState()) {
    load();
  }

  final CouponRepository repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final coupons = await repository.activeCoupons();
      if (isClosed) return;
      emit(state.copyWith(coupons: coupons, isLoading: false));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
      addError(error, stackTrace);
    }
  }
}
