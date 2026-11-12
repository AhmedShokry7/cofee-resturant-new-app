import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_offboarding.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_offboarding_repository.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_offboarding_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// منطق إنهاء الخدمة على ملف موظف واحد: الحالة والخطوات وكل قرار.
///
/// الكتابة تسير في مسار واحد: قفل، إرسال، ثم نجاحٌ يعيد قراءة الحالة من
/// القاعدة، أو رفضٌ يبقى نصّه كما قالته.
class HrOffboardingCubit extends Cubit<HrOffboardingState> {
  HrOffboardingCubit({
    HrOffboardingRepository? repository,
  })  : _repository = repository ?? HrDependencies.offboarding,
        super(const HrOffboardingState());

  final HrOffboardingRepository _repository;

  /// الموظف المفتوح ملفُه، الذي تُقرأ له الحالة.
  String? staffId;

  Future<void> load(String targetStaffId) async {
    staffId = targetStaffId;
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      final cases = await _repository.loadCases(staffId: targetStaffId);
      emit(state.copyWith(
        status: HrLoadStatus.ready,
        cases: cases,
        clearFailure: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: HrLoadStatus.failure,
        failure: hrRefusalOf(error),
      ));
    }
  }

  /// يقرأ الحالة المفتوحة إن وُجدت، وإلا آخر حالة (تاريخية).
  HrOffboardingCase? get current {
    if (state.cases.isEmpty) return null;
    for (final item in state.cases) {
      if (item.isOpen) return item;
    }
    return state.cases.first;
  }

  Future<void> start({
    required String targetStaffId,
    DateTime? lastWorkingOn,
    String? note,
  }) =>
      _write(
        () => _repository.start(
          staffId: targetStaffId,
          lastWorkingOn: lastWorkingOn,
          note: note,
        ),
      );

  Future<void> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  }) =>
      _write(
        () => _repository.assignStep(
          caseId: caseId,
          code: code,
          ownerStaffId: ownerStaffId,
          dueOn: dueOn,
        ),
      );

  Future<void> setStep({
    required String caseId,
    required String code,
    required String status,
    String? note,
  }) =>
      _write(
        () => _repository.setStep(
          caseId: caseId,
          code: code,
          status: status,
          note: note,
        ),
      );

  Future<void> cancel({required String caseId, String? note}) =>
      _write(() => _repository.cancel(caseId: caseId, note: note));

  Future<void> finalize({
    required String caseId,
    DateTime? terminatedOn,
    String? note,
  }) =>
      _write(
        () => _repository.finalize(
          caseId: caseId,
          terminatedOn: terminatedOn,
          note: note,
        ),
      );

  Future<void> suspendAccess({required String caseId, String? note}) =>
      _write(() => _repository.suspendAccess(caseId: caseId, note: note));

  Future<void> _write(Future<HrOffboardingCase> Function() send) async {
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    HrRefusal? failure;
    try {
      final updated = await send();
      final replaced = state.cases
          .where((item) => item.caseId != updated.caseId)
          .toList()
        ..insert(0, updated);
      emit(state.copyWith(cases: replaced, clearFailure: true));
    } catch (error) {
      failure = hrRefusalOf(error);
    }
    emit(state.copyWith(
      writing: HrWriteStatus.done,
      failure: failure,
      clearFailure: failure == null,
    ));
  }
}
