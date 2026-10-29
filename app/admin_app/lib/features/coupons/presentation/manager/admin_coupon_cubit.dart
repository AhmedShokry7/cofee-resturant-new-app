import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/di/coupons_dependencies.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';
import 'package:admin_app/features/coupons/domain/usecases/delete_coupon.dart';
import 'package:admin_app/features/coupons/domain/usecases/load_coupons.dart';
import 'package:admin_app/features/coupons/domain/usecases/load_metrics.dart';
import 'package:admin_app/features/coupons/domain/usecases/load_targets.dart';
import 'package:admin_app/features/coupons/domain/usecases/save_coupon.dart';
import 'package:admin_app/features/coupons/domain/usecases/set_coupon_active.dart';
import 'package:admin_app/features/coupons/presentation/manager/admin_coupon_state.dart';

class AdminCouponCubit extends Cubit<AdminCouponState> {
  AdminCouponCubit({CouponRepository? repository})
    : this._withUseCases(repository ?? CouponsDependencies.repository);

  AdminCouponCubit._withUseCases(CouponRepository repository)
    : _loadCoupons = LoadCouponsUseCase(repository),
      _loadMetrics = LoadMetricsUseCase(repository),
      _loadTargets = LoadTargetsUseCase(repository),
      _saveCoupon = SaveCouponUseCase(repository),
      _setCouponActive = SetCouponActiveUseCase(repository),
      _deleteCoupon = DeleteCouponUseCase(repository),
      super(const AdminCouponState());

  final LoadCouponsUseCase _loadCoupons;
  final LoadMetricsUseCase _loadMetrics;
  final LoadTargetsUseCase _loadTargets;
  final SaveCouponUseCase _saveCoupon;
  final SetCouponActiveUseCase _setCouponActive;
  final DeleteCouponUseCase _deleteCoupon;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(
      state.copyWith(status: AdminCouponPageStatus.loading, clearError: true),
    );
    try {
      final results = await Future.wait<Object>([
        _loadCoupons(),
        _loadMetrics(),
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
      final targets = await _loadTargets();
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
    final CouponSaveOutcome outcome;
    try {
      outcome = await _saveCoupon(draft);
    } catch (_) {
      // قواعد الكوبون ترفض بـ42501 (168 تطلب settings.write على الأهداف). بلا
      // هذا التحويل يسقط الاستثناء في المنادي فلا تصل النافذة أبدًا إلى حالة
      // الفشل، وتبقى معلّقة على زر الحفظ بلا إغلاق.
      return CouponSaveOutcome.failed;
    }
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
    final CouponMutationOutcome outcome;
    try {
      outcome = await _setCouponActive(couponId, active);
    } catch (_) {
      return CouponMutationOutcome.failed;
    }
    if (outcome == CouponMutationOutcome.success) await load();
    return outcome;
  }

  Future<CouponMutationOutcome> deleteCoupon(String couponId) async {
    final CouponMutationOutcome outcome;
    try {
      outcome = await _deleteCoupon(couponId);
    } catch (_) {
      return CouponMutationOutcome.failed;
    }
    if (outcome == CouponMutationOutcome.success) await load();
    return outcome;
  }

  Future<void> _refreshTargets() async {
    if (state.targets.isEmpty) return;
    try {
      final targets = await _loadTargets();
      emit(state.copyWith(targets: targets));
    } catch (_) {
      // The editor reloads the catalogue the next time it opens.
    }
  }
}
