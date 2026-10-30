import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_dashboard_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// لوحة القوى العاملة: عددٌ وحضورٌ وانتظارٌ ومال، من سؤال واحد في القاعدة.
///
/// الأرقام كلها من `admin_hr_dashboard` كما رأتها صلاحية السائل ونطاقه، فلا
/// تجمع الشاشة عدّها من صفحات أخرى ولا تعرف شيئًا لم يُسمح لها به.
class HrDashboardCubit extends Cubit<HrDashboardState> {
  HrDashboardCubit({HrPeopleRepository? repository})
    : _repository = repository ?? HrDependencies.people,
      super(const HrDashboardState());

  final HrPeopleRepository _repository;

  Future<void> load({String? branchId}) async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          dashboard: await _repository.loadDashboard(branchId: branchId),
          branchId: branchId,
          clearBranch: branchId == null,
          clearFailure: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: HrLoadStatus.failure,
          failure: hrRefusalOf(error),
        ),
      );
    }
  }

  Future<void> selectBranch(String? branchId) => load(branchId: branchId);
}
