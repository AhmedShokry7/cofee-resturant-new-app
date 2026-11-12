import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll_preview.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';

/// عقد الرواتب: التركيب، ثم الدورة، ثم قرار المراجعة.
///
/// لا تجمع أي شاشة أسطرًا لتحصل على الإجمالي: القاعدة تكتب `gross` و`net` مرة
/// عند الحساب، وتكرار الجمع في Dart يخالف المعتمد عند أي كسر عشري.
abstract interface class HrPayrollRepository {
  /// كتابة تركيبة الأجر؛ تاريخ النفاذ يفتح فترة جديدة ولا يمحى القديمة.
  Future<HrReceipt> setCompensation({
    required String staffId,
    required double basicSalary,
    double housingAllowance = 0,
    double transportAllowance = 0,
    double otherAllowance = 0,
    DateTime? effectiveFrom,
    String? note,
  });

  /// حساب دورة شهر واحد. إعادة الحساب على مسودة محسوبة تستبدل قسيماتها.
  Future<HrReceipt> generatePayroll({
    required int periodYear,
    required int periodMonth,
    String? note,
  });

  Future<List<HrPayrollRun>> loadPayrollRuns({int limit = 24});

  /// دورة واحدة مع قسيماتها، في نطاق يراه القارئ وحده.
  Future<HrPayrollRun> loadPayrollRun(String runId);

  Future<HrPayrollStatement> loadStatement(String statementId);

  /// قسيمات الموظف نفسه، وهي كل ما يراه الموظف عن ماله.
  Future<List<HrPayrollStatement>> loadMyPayslips();

  /// الاعتماد لا ينفذ دفعًا: يفصل `approved` عن `paid` حتى يبقى المال قرارًا ثانيًا.
  /// ولا رجوع فيه — الإلغاء وحده `cancelPayrollRun`، و`hr.payroll.approve` لا
  /// تملكها أي دور في 212 فيمنحها المالك فقط، ومن يدير الرواتب لا يعتمد دورته.
  Future<HrReceipt> approvePayroll({required String runId, String? note});

  Future<HrReceipt> payPayroll({required String runId, String? note});

  Future<HrReceipt> cancelPayrollRun({required String runId, String? note});

  /// الخطأ في قسيمة معتمدة لا يُعدّل في الصف: correction تسوية معلقة لدورة
  /// لاحقة، وتُراجع كأي تسوية أخرى.
  Future<HrReceipt> payrollCorrection({
    required String statementId,
    required String kind,
    required double amount,
    required String reason,
    DateTime? effectiveDate,
  });

  /// معاينة قراءة قبل التوليد: مدخلات الفترة، بياناتها الناقصة، ومطابقة
  /// احتساب لكل موظف — بلا كتابة واحدة.
  Future<HrPayrollPreview> previewPayroll({
    required int periodYear,
    required int periodMonth,
  });

  /// إقفال فترة صُرفت: خاتم نهائي يمنع التصحيح اللاحق على قسائمها، ويُدقَّق
  /// كأي قرار مالي.
  Future<HrReceipt> closePeriod({required String runId, String? note});
}
