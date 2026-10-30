import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee_file.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';

/// عقد قراءة الموظفين وكتابتهم، وكل ما فيه من `admin_hr_*` في 212.
///
/// لا تُعرف هنا أي استعارة JSON ولا أي خطأ شبكة: التنفيذ يحوّل، والشاشة تسأل عن
/// الكيانات. وبهذا تُختبر اللوحة بديلًا يكتب صفوفًا، لا اتصالًا وهميًا.
abstract interface class HrPeopleRepository {
  /// قوائم الاختيار وسياسة النطاق ومنطق المنطقة التجارية للقارئ.
  Future<HrReference> loadReference();

  /// الدليل: بحث ونطاق فرع وحالة توظيف وقسم.
  Future<List<HrEmployee>> loadEmployees({
    String? search,
    String? branchId,
    String? status,
    String? department,
  });

  /// ملف موظف واحد بأقسامه المرخّص منها.
  Future<HrEmployeeFile> loadEmployeeFile(String staffId);

  /// كتابة سجل التوظيف. القاعدة تكتب كل الأعمدة، فالحقل المُهمل يُمسح،
  /// وتعيد الصف كما ختمته هي — لا ما أرسلته الشاشة.
  Future<HrEmployment> saveEmployment({
    required String staffId,
    String? employeeNumber,
    String? department,
    String? jobTitle,
    String? employmentType,
    String? employmentStatus,
    DateTime? hiredOn,
    DateTime? terminatedOn,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? notes,
  });

  /// لوحة HR في نطاق فرع، أو في نطاق القارئ حين لا فرع.
  Future<HrDashboard> loadDashboard({String? branchId});

  /// سياسة HR؛ null لكل ما لا يريد المدير تغييره، فالقاعدة تبقيه.
  Future<HrSettings> updateSettings({
    String? businessTimeZone,
    int? lateGraceMinutes,
    double? lateMinuteRate,
    double? earlyMinuteRate,
    double? absenceDayRate,
    bool? cashierDeductionAllowed,
    double? maxSalaryDeductionPercent,
  });

  /// نوع إجازة جديد أو تعديل على قائم؛ `code` لا يتغير بعد الإنشاء.
  Future<HrReceipt> saveLeaveType({
    String? id,
    String? code,
    String? nameAr,
    String? nameEn,
    bool requiresDocument = false,
    bool isPaid = true,
    bool tracksBalance = false,
    double? defaultAnnualDays,
    bool isActive = true,
  });
}
