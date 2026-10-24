import 'package:admin_app/core/locale/app_locale.dart';

class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    this.actorUserId,
    this.actorName,
    this.actorEmail,
    this.actorRole,
    required this.action,
    required this.entityType,
    this.entityId,
    this.branchId,
    this.branchNameAr,
    this.branchNameEn,
    this.oldValues,
    this.newValues,
    this.createdAt,
  });

  final int id;
  final String? actorUserId;
  final String? actorName;
  final String? actorEmail;
  final String? actorRole;
  final String action;
  final String entityType;
  final String? entityId;
  final String? branchId;
  final String? branchNameAr;
  final String? branchNameEn;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final DateTime? createdAt;

  String branchNameFor(AppLanguage language) {
    if (language.isArabic) return branchNameAr?.trim() ?? '';
    return branchNameEn?.trim() ?? '';
  }

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      actorUserId: json['actor_user_id'] as String?,
      actorName: json['actor_name'] as String?,
      actorEmail: json['actor_email'] as String?,
      actorRole: json['actor_role'] as String?,
      action: '${json['action'] ?? ''}',
      entityType: '${json['entity_type'] ?? ''}',
      entityId: json['entity_id'] as String?,
      branchId: json['branch_id'] as String?,
      branchNameAr: json['branch_name_ar'] as String?,
      branchNameEn: json['branch_name_en'] as String?,
      oldValues: json['old_values'] is Map
          ? Map<String, dynamic>.from(json['old_values'] as Map)
          : null,
      newValues: json['new_values'] is Map
          ? Map<String, dynamic>.from(json['new_values'] as Map)
          : null,
      createdAt: _toDateTime(json['created_at']),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
