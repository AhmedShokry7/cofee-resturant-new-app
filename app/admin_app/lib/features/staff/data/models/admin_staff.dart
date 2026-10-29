import 'package:admin_app/core/locale/app_locale.dart';

class AdminStaffRole {
  const AdminStaffRole({
    required this.roleId,
    required this.roleCode,
    this.branchId,
  });

  final String roleId;
  final String roleCode;
  final String? branchId;

  factory AdminStaffRole.fromJson(Map<String, dynamic> json) {
    return AdminStaffRole(
      roleId: '${json['role_id'] ?? ''}',
      roleCode: '${json['role_code'] ?? ''}',
      branchId: json['branch_id'] as String?,
    );
  }
}

class AdminStaffMember {
  const AdminStaffMember({
    required this.id,
    required this.userId,
    this.fullName,
    this.email,
    required this.status,
    this.avatarUrl,
    this.createdAt,
    this.acceptedAt,
    this.roles = const <AdminStaffRole>[],
    this.permissions = const <String>[],
  });

  final String id;
  final String userId;
  final String? fullName;
  final String? email;
  final String status;

  /// The picture as the repository hands it out: a signed display URL when the
  /// object of `staff/<id>/…` could be signed, the stored path when it could
  /// not (migration `209_staff_profile_edit_and_avatar.sql`), nothing when the
  /// account has no picture.
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final List<AdminStaffRole> roles;
  final List<String> permissions;

  String displayName() {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    return id;
  }

  factory AdminStaffMember.fromJson(Map<String, dynamic> json) {
    final rolesRaw = json['roles'] as List<dynamic>?;
    final permsRaw = json['permissions'] as List<dynamic>?;
    return AdminStaffMember(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      status: '${json['status'] ?? ''}',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: _toDateTime(json['created_at']),
      acceptedAt: _toDateTime(json['accepted_at']),
      roles:
          rolesRaw
              ?.map(
                (e) => AdminStaffRole.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <AdminStaffRole>[],
      permissions: permsRaw?.map((e) => '$e').toList() ?? const <String>[],
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}

/// دعوة لم تُقبل بعد، كما يصفها `public.admin_staff_invitations()`.
///
/// الحالة هنا هي الحالة المعروضة لا المخزَّنة: القاعدة تضيف ساعتها فتقول
/// `expired` لصف ما زال `pending` لكنه تجاوز أجله، فلا تحتاج الشاشة مقارنة
/// تواريخ. و`token` يصل فقط للموظف الذي كتب الدعوة أو لمن يدير كل الفروع،
/// ولهذا يكون `null` في القائمة التي يقرأها مدير فرعٍ آخر.
class AdminStaffInvitation {
  const AdminStaffInvitation({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roleCode,
    required this.roleNameAr,
    required this.roleNameEn,
    this.branchId,
    this.branchNameAr,
    this.branchNameEn,
    required this.status,
    this.invitedAt,
    this.expiresAt,
    this.acceptedAt,
    this.invitedByName,
    this.token,
  });

  final String id;
  final String email;
  final String fullName;
  final String roleCode;
  final String roleNameAr;
  final String roleNameEn;
  final String? branchId;
  final String? branchNameAr;
  final String? branchNameEn;

  /// `pending` أو `accepted` أو `cancelled` أو `expired`.
  final String status;
  final DateTime? invitedAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final String? invitedByName;

  /// رمز القبول، ويصل كما هو من القاعدة أو لا يصل.
  final String? token;

  bool get isPending => status == 'pending';

  /// الرمز قابل للمشاركته: لم يُستخدم ولم ينتهِ ولم تُحجبه القاعدة.
  bool get canShareCode => isPending && (token?.trim().isNotEmpty ?? false);

  String roleName() => AppLocale.instance.isArabic ? roleNameAr : roleNameEn;

  /// اسم الفرع، أو ما يقول إن الدعوة على مستوى المنصة كله حين لا فرع لها.
  String branchName(String fallback) {
    if (branchId == null) return fallback;
    final name = AppLocale.instance.isArabic ? branchNameAr : branchNameEn;
    return (name?.trim().isNotEmpty ?? false) ? name! : fallback;
  }

  factory AdminStaffInvitation.fromJson(Map<String, dynamic> json) {
    return AdminStaffInvitation(
      id: '${json['id'] ?? ''}',
      email: '${json['email'] ?? ''}',
      fullName: '${json['full_name'] ?? ''}',
      roleCode: '${json['role_code'] ?? ''}',
      roleNameAr: '${json['role_name_ar'] ?? ''}',
      roleNameEn: '${json['role_name_en'] ?? ''}',
      branchId: json['branch_id'] as String?,
      branchNameAr: json['branch_name_ar'] as String?,
      branchNameEn: json['branch_name_en'] as String?,
      status: '${json['status'] ?? ''}',
      invitedAt: AdminStaffMember._toDateTime(json['invited_at']),
      expiresAt: AdminStaffMember._toDateTime(json['expires_at']),
      acceptedAt: AdminStaffMember._toDateTime(json['accepted_at']),
      invitedByName: '${json['invited_by_name'] ?? ''}',
      token: json['token'] == null ? null : '${json['token']}',
    );
  }
}

/// ما يجوز أن يعرضه نموذج الدعوة من أدوار وفروع، كما تجيب به
/// `public.admin_staff_invite_options()` — وهو مقصوص على Caller نفسه، فلا يعرض
/// خيارًا كان سيرفضه خطوة الحفظ.
class AdminInviteOptions {
  const AdminInviteOptions({
    this.roles = const <AdminInviteChoice>[],
    this.branches = const <AdminInviteChoice>[],
    this.canOfferAnyBranch = false,
  });

  final List<AdminInviteChoice> roles;
  final List<AdminInviteChoice> branches;

  /// هل يملك هذا الموظف أن يدعو بلا فرع، أي على مستوى المنصة كله.
  final bool canOfferAnyBranch;

  factory AdminInviteOptions.fromJson(Map<String, dynamic> json) {
    return AdminInviteOptions(
      roles: _choices(json['roles']),
      branches: _choices(json['branches']),
      canOfferAnyBranch: json['can_offer_any_branch'] == true,
    );
  }

  static List<AdminInviteChoice> _choices(Object? raw) {
    if (raw is! List) return const <AdminInviteChoice>[];
    return raw
        .whereType<Map>()
        .map(
          (row) => AdminInviteChoice.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }
}

/// دور أو فرع كما يسميه الموظف بلغته.
class AdminInviteChoice {
  const AdminInviteChoice({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  String name() => AppLocale.instance.isArabic ? nameAr : nameEn;

  factory AdminInviteChoice.fromJson(Map<String, dynamic> json) {
    // الدور بلا مفتاح رقمي في الرد: رمزه هو ما تُسلَّم للدعوة، والفرع له UUID.
    final identifier = json['code'] ?? json['id'] ?? '';
    return AdminInviteChoice(
      id: '$identifier',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
    );
  }
}
