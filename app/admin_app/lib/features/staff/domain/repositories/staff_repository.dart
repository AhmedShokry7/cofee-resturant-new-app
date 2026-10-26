import 'package:admin_app/features/staff/data/models/admin_staff.dart';

/// عقد قراءة الموظفين والصلاحيات وكتابة ارتباطاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class StaffRepository {
  /// يقرأ كل الموظفين بترتيب القاعدة.
  Future<List<AdminStaffMember>> loadStaff();

  /// يقرأ كتالوج الصلاحيات كصفوف خام.
  Future<List<Map<String, dynamic>>> loadPermissions();

  /// يمنح صلاحية لموظف أو يسحبها بعد فحص القاعدة.
  Future<void> setStaffPermission(
    String staffId,
    String permissionCode,
    bool granted,
  );
}
