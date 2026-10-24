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

  String displayName() {
    if (nameEn != null && nameEn!.trim().isNotEmpty) return nameEn!.trim();
    if (nameAr != null && nameAr!.trim().isNotEmpty) return nameAr!.trim();
    return code;
  }

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
