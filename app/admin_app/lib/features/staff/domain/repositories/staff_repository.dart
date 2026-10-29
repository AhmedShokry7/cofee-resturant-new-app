import 'dart:typed_data';

import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/domain/entities/staff_edit_outcome.dart';
import 'package:admin_app/features/staff/domain/entities/staff_invite_outcome.dart';

/// عقد قراءة الموظفين والصلاحيات وكتابة ارتباطاتهما وبيانات الحساب.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class StaffRepository {
  /// يقرأ كل الموظفين بترتيب القاعدة، وصورهم روابط صالحة للعرض.
  Future<List<AdminStaffMember>> loadStaff();

  /// يقرأ كتالوج الصلاحيات كصفوف خام.
  Future<List<Map<String, dynamic>>> loadPermissions();

  /// يمنح صلاحية لموظف أو يسحبها بعد فحص القاعدة.
  Future<void> setStaffPermission(
    String staffId,
    String permissionCode,
    bool granted,
  );

  /// يغيّر الاسم أو البريد أو الحالة؛ الفراغ يعني «اترك الحقل كما هو»، وهو ما
  /// يقرره `public.admin_update_staff` لا الشاشة.
  Future<StaffEditOutcome> updateStaff({
    required String staffId,
    String? fullName,
    String? email,
    String? status,
  });

  /// يسجل مسار صورة الموظف داخل دلو `avatars`، أو يفرّغه عند تمرير فراغ.
  Future<StaffEditOutcome> setStaffImage(String staffId, String? path);

  /// يرفع الملف إلى مجلد الموظف ثم يكتب مساره، ويحذف ما رفعه إن لم تُكتب الصورة.
  Future<StaffEditOutcome> uploadStaffImage({
    required String staffId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String? replaces,

    /// تُبلَّغ المرحلة ليُقال للموظف أي خطوة تجري الآن.
    void Function(AdminImageUploadPhase phase)? onPhase,
  });

  /// يحذف ملف الصورة نفسه بعد أن أفرغ الصف مساره.
  Future<void> deleteStaffImageFile(String? displayedUrl);

  /// يقرأ الدعوات التي لم تُقبل بعد مع حالتها كما تُقيّمها القاعدة في لحظة القراءة.
  Future<List<AdminStaffInvitation>> loadInvitations();

  /// الأدوار والفروع التي يملك هذا الموظف أن يضعها في دعوة؛ لا ما يوجد في
  /// الكتالوج كله.
  Future<AdminInviteOptions> loadInviteOptions();

  /// يكتب دعوة ويأتي برمزها، أو بسبب رفض القاعدة.
  Future<StaffInviteResult> inviteStaff({
    required String email,
    required String fullName,
    required String roleCode,
    String? branchId,
  });

  /// يسحب دعوة لم تُقبل بعد؛ ترفضها القاعدة إن كانت خارج نطاق كاتبها.
  Future<StaffInviteOutcome> cancelInvitation(String invitationId);
}
