import 'package:admin_app/features/hr/presentation/manager/hr_attempt.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// شاشة إعدادات الموارد البشرية: سياسة العمل وأنواع الإجازة.
///
/// السياسة في `hr.settings` لا في حالة الواجهة، فتُعاد قراءتها بعد كل حفظ كما
/// رآها المرجع. ومن لا يملك `hr.settings.manage` يُرفض سطره في القاعدة —
/// إخفاء الزرّ وحده لا يكفي لأن السؤال يبقى مسموحًا لغيره.
class HrSettingsCubit extends HrReferenceCubit {
  HrSettingsCubit({super.repository});

  Future<bool> updateSettings({
    String? businessTimeZone,
    int? lateGraceMinutes,
    double? lateMinuteRate,
    double? earlyMinuteRate,
    double? absenceDayRate,
    bool? cashierDeductionAllowed,
    double? maxSalaryDeductionPercent,
  }) => _write(
    () => repository.updateSettings(
      businessTimeZone: businessTimeZone,
      lateGraceMinutes: lateGraceMinutes,
      lateMinuteRate: lateMinuteRate,
      earlyMinuteRate: earlyMinuteRate,
      absenceDayRate: absenceDayRate,
      cashierDeductionAllowed: cashierDeductionAllowed,
      maxSalaryDeductionPercent: maxSalaryDeductionPercent,
    ),
  );

  Future<bool> saveLeaveType({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    bool requiresDocument = false,
    bool isPaid = true,
    bool tracksBalance = false,
    double? defaultAnnualDays,
    bool isActive = true,
  }) => _write(
    () => repository.saveLeaveType(
      id: id,
      code: code,
      nameAr: nameAr,
      nameEn: nameEn,
      requiresDocument: requiresDocument,
      isPaid: isPaid,
      tracksBalance: tracksBalance,
      defaultAnnualDays: defaultAnnualDays,
      isActive: isActive,
    ),
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
    if (failure == null) await load();
    return failure == null;
  }
}
