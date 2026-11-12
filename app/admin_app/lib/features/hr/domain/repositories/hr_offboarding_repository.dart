import 'package:admin_app/features/hr/domain/entities/hr_offboarding.dart';

/// عقد إنهاء الخدمة: الحالة وقائمة خطواتها وكل قرار عليها.
///
/// القرارات كلها مُدقَّقة في القاعدة؛ هنا توصيل فقط. لا معادلات مستحقات:
/// التسوية النهائية قرار بشري موثّق في ملاحظة خطوته.
abstract interface class HrOffboardingRepository {
  /// حالات الموظف (عادة حالة واحدة نشطة أو تاريخية بعد الإلغاء).
  Future<List<HrOffboardingCase>> loadCases({String? staffId});

  /// فتح حالة جديدة بقائمة خطواتها؛ رفض القاعدة يمر كما رفعه.
  Future<HrOffboardingCase> start({
    required String staffId,
    DateTime? lastWorkingOn,
    String? note,
  });

  /// إسناد خطوة لمالكها مع تاريخ استحقاق.
  Future<HrOffboardingCase> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  });

  /// تغيير حالة خطوة (done يستلزم ملاحظة في القاعدة).
  Future<HrOffboardingCase> setStep({
    required String caseId,
    required String code,
    required String status,
    String? note,
  });

  /// إلغاء حالة مفتوحة، ويُحرَّر مقعد الموظف لحالة مستقبلية.
  Future<HrOffboardingCase> cancel({required String caseId, String? note});

  /// تنفيذ قرار الإنهاء: يستلزم اكتمال الخطوات الإلزامية، ويُرفض على صاحب
  /// الحالة إلا للـ owner.
  Future<HrOffboardingCase> finalize({
    required String caseId,
    DateTime? terminatedOn,
    String? note,
  });

  /// تعليق الدخول: بعد الإقفال فقط، مرة واحدة، مُدقَّق.
  Future<HrOffboardingCase> suspendAccess({
    required String caseId,
    String? note,
  });
}
