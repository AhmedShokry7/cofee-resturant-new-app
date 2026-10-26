import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_targets.dart';

enum AdminCouponPageStatus { initial, loading, ready, failure }

class AdminCouponState {
  const AdminCouponState({
    this.status = AdminCouponPageStatus.initial,
    this.coupons = const <AdminCoupon>[],
    this.metrics = AdminCouponMetrics.empty,
    this.targets = AdminCouponTargets.empty,
    this.targetsLoading = false,
    this.targetsError,
    this.errorMessage,
  });

  final AdminCouponPageStatus status;
  final List<AdminCoupon> coupons;
  final AdminCouponMetrics metrics;
  final AdminCouponTargets targets;
  final bool targetsLoading;
  final String? targetsError;
  final String? errorMessage;

  bool get isLoading => status == AdminCouponPageStatus.loading;
  bool get isFailure => status == AdminCouponPageStatus.failure;

  bool get hasData => coupons.isNotEmpty || metrics.total > 0;

  AdminCouponState copyWith({
    AdminCouponPageStatus? status,
    List<AdminCoupon>? coupons,
    AdminCouponMetrics? metrics,
    AdminCouponTargets? targets,
    bool? targetsLoading,
    String? targetsError,
    String? errorMessage,
    bool clearError = false,
    bool clearTargetsError = false,
  }) {
    return AdminCouponState(
      status: status ?? this.status,
      coupons: coupons ?? this.coupons,
      metrics: metrics ?? this.metrics,
      targets: targets ?? this.targets,
      targetsLoading: targetsLoading ?? this.targetsLoading,
      targetsError: clearTargetsError
          ? null
          : (targetsError ?? this.targetsError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
