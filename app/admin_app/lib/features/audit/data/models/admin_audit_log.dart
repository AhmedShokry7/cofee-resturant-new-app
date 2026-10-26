import 'package:admin_app/core/locale/app_locale.dart';

class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    this.actorUserId,
    this.actorName,
    this.actorEmail,
    this.actorRole,
    this.actorRolesAr = const <String>[],
    this.actorRolesEn = const <String>[],
    required this.action,
    this.domain = '',
    this.isCritical = false,
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

  /// The database role recorded by identity.audit(); kept for the technical
  /// details only. Admin roles come from [actorRolesAr] and [actorRolesEn].
  final String? actorRole;
  final List<String> actorRolesAr;
  final List<String> actorRolesEn;
  final String action;
  final String domain;
  final bool isCritical;
  final String entityType;
  final String? entityId;
  final String? branchId;
  final String? branchNameAr;
  final String? branchNameEn;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final DateTime? createdAt;

  String branchNameFor(AppLanguage language) {
    final primary = language.isArabic ? branchNameAr : branchNameEn;
    final fallback = language.isArabic ? branchNameEn : branchNameAr;
    final name = primary?.trim();
    if (name != null && name.isNotEmpty) return name;
    return fallback?.trim() ?? '';
  }

  /// The first part of the action code, such as `core` or `marketing`.
  String get actionDomain {
    if (domain.trim().isNotEmpty) return domain.trim();
    final index = action.indexOf('.');
    return index <= 0 ? action : action.substring(0, index);
  }

  List<String> actorRolesFor(AppLanguage language) {
    final primary = language.isArabic ? actorRolesAr : actorRolesEn;
    if (primary.isNotEmpty) return primary;
    return language.isArabic ? actorRolesEn : actorRolesAr;
  }

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    final action = '${json['action'] ?? ''}';
    final domain = '${json['domain'] ?? ''}'.trim();
    return AdminAuditLog(
      id: _toInt(json['id']),
      actorUserId: json['actor_user_id'] as String?,
      actorName: json['actor_name'] as String?,
      actorEmail: json['actor_email'] as String?,
      actorRole: json['actor_role'] as String?,
      actorRolesAr: _toTextList(json['actor_roles_ar']),
      actorRolesEn: _toTextList(json['actor_roles_en']),
      action: action,
      domain: domain.isNotEmpty
          ? domain
          : (action.contains('.') ? action.split('.').first : action),
      isCritical: json['is_critical'] == true,
      entityType: '${json['entity_type'] ?? ''}',
      entityId: json['entity_id'] as String?,
      branchId: json['branch_id'] as String?,
      branchNameAr: json['branch_name_ar'] as String?,
      branchNameEn: json['branch_name_en'] as String?,
      oldValues: _toMap(json['old_values']),
      newValues: _toMap(json['new_values']),
      createdAt: _toDateTime(json['created_at']),
    );
  }

  static int _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static List<String> _toTextList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<Object>()
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic>? _toMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}

class AdminAuditPage {
  const AdminAuditPage({this.rows = const <AdminAuditLog>[], this.total = 0});

  final List<AdminAuditLog> rows;

  /// The number of rows the server matched, across every page.
  final int total;

  factory AdminAuditPage.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return AdminAuditPage(
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) =>
                      AdminAuditLog.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList(growable: false)
          : const <AdminAuditLog>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
