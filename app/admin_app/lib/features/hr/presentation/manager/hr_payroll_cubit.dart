import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_payroll_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_attempt.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_payroll_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// دورات الرواتب: توليد الشهر، ثم اعتماد، ثم صرف، مع تركيبة أجر الموظف.
///
/// الآلة حالةٌ في القاعدة لا في الشاشة: draft ← calculated ← approved ← paid،
/// ولا يرجع منها شيء إلا بالإلغاء من حالة تسمح به، فيبقى رفض 23514 معروضًا
/// بحروفه حين يضغط من لا يملك الدور السطر.
class HrPayrollCubit extends Cubit<HrPayrollState> {
  HrPayrollCubit({HrPayrollRepository? repository})
    : _repository = repository ?? HrDependencies.payroll,
      super(const HrPayrollState());

  final HrPayrollRepository _repository;

  int limit = 24;

  Future<void> reload() async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          runs: await _repository.loadPayrollRuns(limit: limit),
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

  Future<void> openRun(String runId) async {
    emit(state.copyWith(clearFailure: true));
    try {
      emit(state.copyWith(run: await _repository.loadPayrollRun(runId)));
    } catch (error) {
      emit(state.copyWith(clearRun: true, failure: hrRefusalOf(error)));
    }
  }

  Future<void> openStatement(String statementId) async {
    emit(state.copyWith(clearFailure: true));
    try {
      emit(
        state.copyWith(statement: await _repository.loadStatement(statementId)),
      );
    } catch (error) {
      emit(state.copyWith(clearStatement: true, failure: hrRefusalOf(error)));
    }
  }

  void closeRun() => emit(state.copyWith(clearRun: true, clearStatement: true));

  /// الرجوع من قسيمة إلى دورتها: القسيمة تُغلق وحدها، فتبقى الدورة مفتوحة.
  void closeStatement() => emit(state.copyWith(clearStatement: true));

  Future<bool> generate({
    required int periodYear,
    required int periodMonth,
    String? note,
  }) => _write(
    () => _repository.generatePayroll(
      periodYear: periodYear,
      periodMonth: periodMonth,
      note: note,
    ),
  );

  Future<bool> approve({required String runId, String? note}) =>
      _write(() => _repository.approvePayroll(runId: runId, note: note));

  Future<bool> pay({required String runId, String? note}) =>
      _write(() => _repository.payPayroll(runId: runId, note: note));

  Future<bool> cancel({required String runId, String? note}) =>
      _write(() => _repository.cancelPayrollRun(runId: runId, note: note));

  /// تسوية على قسيمة معتمدة: سطر إضافي في الدورة القادمة لا تعديل على صورة
  /// القسيمة التي استلمها الموظف.
  Future<bool> correction({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  }) => _write(
    () => _repository.payrollCorrection(
      statementId: statementId,
      kind: kind,
      amount: amount,
      reason: reason,
      effectiveDate: effectiveDate,
    ),
  );

  Future<bool> setCompensation({
    required String staffId,
    required double basicSalary,
    double housingAllowance = 0,
    double transportAllowance = 0,
    double otherAllowance = 0,
    DateTime? effectiveFrom,
    String? note,
  }) => _write(
    () => _repository.setCompensation(
      staffId: staffId,
      basicSalary: basicSalary,
      housingAllowance: housingAllowance,
      transportAllowance: transportAllowance,
      otherAllowance: otherAllowance,
      effectiveFrom: effectiveFrom,
      note: note,
    ),
  );

  /// معاينة الفترة قبل التوليد أو على دورة قائمة: قراءة نقية من القاعدة.
  Future<void> loadPreview({required int periodYear, required int periodMonth}) async {
    emit(state.copyWith(
      previewStatus: HrLoadStatus.loading,
      clearPreviewFailure: true,
    ));
    try {
      emit(
        state.copyWith(
          previewStatus: HrLoadStatus.ready,
          preview: await _repository.previewPayroll(
            periodYear: periodYear,
            periodMonth: periodMonth,
          ),
          clearPreviewFailure: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          previewStatus: HrLoadStatus.failure,
          previewFailure: hrRefusalOf(error),
        ),
      );
    }
  }

  /// إغلاق فترة صُرفت: خاتم نهائي، ثم تُعاد الدورة المفتوحة بحالتها الجديدة.
  Future<bool> closePeriod({required String runId, String? note}) => _write(
        () => _repository.closePeriod(runId: runId, note: note),
      );

  Future<bool> _write(Future<Object?> Function() send) async {
    emit(state.copyWith(writing: HrWriteStatus.sending, clearFailure: true));
    final failure = await hrAttempt(send);
    emit(
      state.copyWith(
        writing: HrWriteStatus.done,
        failure: failure,
        clearFailure: failure == null,
      ),
    );
    // الدورة المفتوحة تُعاد قراءتها هي الأخرى: اعتمادٌ غيّر حالتها وقسيماتها.
    if (failure == null) {
      final open = state.run;
      await reload();
      if (open != null) await openRun(open.runId);
    }
    return failure == null;
  }
}
