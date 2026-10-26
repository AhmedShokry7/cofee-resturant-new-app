import 'package:admin_app/core/locale/app_locale.dart';

class AdminKitchenBranchOption {
  const AdminKitchenBranchOption({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool isActive;

  String nameFor(AppLanguage language) {
    final primary = language.isArabic ? nameAr : nameEn;
    final fallback = language.isArabic ? nameEn : nameAr;
    final name = primary.trim();
    if (name.isNotEmpty) return name;
    return fallback.trim();
  }

  factory AdminKitchenBranchOption.fromJson(Map<String, dynamic> json) {
    return AdminKitchenBranchOption(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      isActive: json['is_active'] != false,
    );
  }
}

class AdminKitchenFilters {
  const AdminKitchenFilters({
    this.branches = const <AdminKitchenBranchOption>[],
  });

  static const empty = AdminKitchenFilters();

  final List<AdminKitchenBranchOption> branches;

  bool get hasBranches => branches.isNotEmpty;

  AdminKitchenBranchOption? branchById(String? id) {
    if (id == null) return null;
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  factory AdminKitchenFilters.fromJson(Map<String, dynamic> json) {
    final branches = json['branches'];
    return AdminKitchenFilters(
      branches: branches is List
          ? branches
                .whereType<Map>()
                .map(
                  (row) => AdminKitchenBranchOption.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminKitchenBranchOption>[],
    );
  }
}
