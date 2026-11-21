class AdminRole {
  const AdminRole({
    required this.id,
    required this.code,
    this.nameAr,
    this.nameEn,
    this.isSystem = false,
    this.permissions = const <String>[],
  });

  final String id;
  final String code;
  final String? nameAr;
  final String? nameEn;
  final bool isSystem;
  final List<String> permissions;

  /// The owner role is implicitly granted every permission by the database.
  bool get isOwner => code == 'owner';

  factory AdminRole.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'] as List<dynamic>?;
    return AdminRole(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      isSystem: json['is_system'] == true,
      permissions: perms?.map((e) => '$e').toList() ?? const <String>[],
    );
  }
}
