import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/data/repositories/admin_coupon_repository.dart';
import 'package:admin_app/features/coupons/presentation/manager/admin_coupon_state.dart';

class AdminCouponCubit extends Cubit<AdminCouponState> {
  AdminCouponCubit({AdminCouponRepository? repository})
    : _repository = repository ?? AdminCouponRepository(),
      super(const AdminCouponState());

  final AdminCouponRepository _repository;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(
      state.copyWith(status: AdminCouponPageStatus.loading, clearError: true),
    );
    try {
      final results = await Future.wait<Object>([
        _repository.loadCoupons(),
        _repository.loadMetrics(),
      ]);
      emit(
        state.copyWith(
          status: AdminCouponPageStatus.ready,
          coupons: results[0] as List<AdminCoupon>,
          metrics: results[1] as AdminCouponMetrics,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminCouponPageStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<void> loadTargets() async {
    if (state.targetsLoading) return;
    emit(state.copyWith(targetsLoading: true, clearTargetsError: true));
    try {
      final targets = await _repository.loadTargets();
      emit(
        state.copyWith(
          targets: targets,
          targetsLoading: false,
          clearTargetsError: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(targetsLoading: false, targetsError: '$error'));
    }
  }

  Future<CouponSaveOutcome> saveCoupon(AdminCouponDraft draft) async {
    final outcome = await _repository.saveCoupon(draft);
    if (outcome == CouponSaveOutcome.saved) {
      await load();
      await _refreshTargets();
    }
    return outcome;
  }

  Future<CouponMutationOutcome> setCouponActive(
    String couponId,
    bool active,
  ) async {
    final outcome = await _repository.setCouponActive(couponId, active);
    if (outcome == CouponMutationOutcome.success) await load();
    return outcome;
  }

  Future<CouponMutationOutcome> deleteCoupon(String couponId) async {
    final outcome = await _repository.deleteCoupon(couponId);
    if (outcome == CouponMutationOutcome.success) await load();
    return outcome;
  }

  Future<void> _refreshTargets() async {
    if (state.targets.isEmpty) return;
    try {
      final targets = await _repository.loadTargets();
      emit(state.copyWith(targets: targets));
    } catch (_) {
      // The editor reloads the catalogue the next time it opens.
    }
  }
}
