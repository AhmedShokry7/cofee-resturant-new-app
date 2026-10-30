import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة لوحة القوى العاملة.
class HrDashboardState {
  const HrDashboardState({
    this.status = HrLoadStatus.initial,
    this.dashboard,
    this.branchId,
    this.failure,
  });

  final HrLoadStatus status;

  /// اللوحة نفسها: `null` قبل أن تعود، فلا تُعرض أصفار قبل أول قراءة.
  final HrDashboard? dashboard;

  /// الفرع المختار للسؤال، و`null` معناها كل ما يراه المدير من فروع.
  final String? branchId;

  final HrRefusal? failure;

  bool get isLoading => status == HrLoadStatus.loading;

  HrDashboardState copyWith({
    HrLoadStatus? status,
    HrDashboard? dashboard,
    String? branchId,
    bool clearBranch = false,
    HrRefusal? failure,
    bool clearFailure = false,
  }) => HrDashboardState(
    status: status ?? this.status,
    dashboard: dashboard ?? this.dashboard,
    branchId: clearBranch ? null : (branchId ?? this.branchId),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}
