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

  /// ينشئ دورًا مخصّصًا ويعيد معرّفه. القاعدة تتحقق من الاسم والصلاحيات.
  Future<String> createRole({
    required String nameAr,
    required String nameEn,
    required String description,
    required List<String> permissionCodes,
  });

  /// يحدّث اسم الدور ووصفه وصلاحياته كاملة وبشكل ذرّي.
  Future<void> updateRole({
    required String roleId,
    required String nameAr,
    required String nameEn,
    required String description,
    required List<String> permissionCodes,
  });
}
