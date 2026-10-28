import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/dashboard/di/dashboard_dependencies.dart';
import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:admin_app/features/dashboard/domain/usecases/load_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/usecases/save_revenue_target.dart';
import 'package:admin_app/features/dashboard/presentation/manager/admin_dashboard_state.dart';

/// أرقام لوحة التحكم وهدف الشهر.
///
/// قراءة واحدة لكل مرة يفتح فيها الأدمن اللوحة أو يضغط تحديث: الأرقام تجميعات
/// من القاعدة، فأي نصف رقم محسوب هنا سيكون كذبة ثانية تختلف عن الأولى. وبعد
/// حفظ الهدف تُعاد القراءة بدل تعديل الرقم محليًا، فالقاعدة هي التي تقرّب
/// المبلغ وهي التي تعرف هل انكتب أصلًا.
class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  AdminDashboardCubit({DashboardRepository? repository})
    : _loadMetrics = LoadDashboardMetricsUseCase(
        repository ?? DashboardDependencies.repository,
      ),
      _saveTarget = SaveRevenueTargetUseCase(
        repository ?? DashboardDependencies.repository,
      ),
      super(const AdminDashboardState());

  final LoadDashboardMetricsUseCase _loadMetrics;
  final SaveRevenueTargetUseCase _saveTarget;

  Future<void> load() async {
    emit(
      state.copyWith(status: AdminDashboardStatus.loading, clearError: true),
    );
    try {
      final metrics = await _loadMetrics();
      emit(
        state.copyWith(
          status: AdminDashboardStatus.ready,
          metrics: metrics,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminDashboardStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  /// يصفّي اللوحة نصًّا: لا قراءة جديدة، فما يُكتب لا يغيّر رقمًا في القاعدة.
  void search(String query) => emit(state.copyWith(searchQuery: query));

  /// يغيّر مدى منحنى المبيعات بين أسبوع وشهر.
  void setSalesRange(int days) => emit(state.copyWith(salesRangeDays: days));

  /// يحفظ الهدف ثم يعيد القراءة، ويرجع `true` حين نجح الحفظ.
  Future<bool> saveRevenueTarget(double? value) async {
    emit(
      state.copyWith(
        targetStatus: AdminDashboardTargetStatus.saving,
        clearTargetError: true,
      ),
    );
    try {
      await _saveTarget(value);
    } catch (error) {
      emit(
        state.copyWith(
          targetStatus: AdminDashboardTargetStatus.failure,
          targetError: '$error',
        ),
      );
      return false;
    }
    emit(state.copyWith(targetStatus: AdminDashboardTargetStatus.idle));
    await load();
    return true;
  }
}
