import 'package:admin_app/features/roles/data/models/admin_role.dart';

/// عقد قراءة الأدوار والصلاحيات وكتابة ارتباطاتها.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class RoleRepository {
  /// يقرأ كل الأدوار بترتيب القاعدة.
  Future<List<AdminRole>> loadRoles();

  /// يقرأ كتالوج الصلاحيات كصفوف خام.
  Future<List<Map<String, dynamic>>> loadPermissions();

  /// يمنح صلاحية لوظيفة أو يسحبها بعد فحص القاعدة.
  Future<void> setRolePermission(String roleId, String code, bool granted);
}
