import 'package:admin_app/core/locale/app_locale.dart';

class AdminInventoryBranchOption {
  const AdminInventoryBranchOption({
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

  factory AdminInventoryBranchOption.fromJson(Map<String, dynamic> json) {
    return AdminInventoryBranchOption(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      isActive: json['is_active'] != false,
    );
  }
}

class AdminInventoryCategoryOption {
  const AdminInventoryCategoryOption({required this.value, this.count = 0});

  final String value;
  final int count;

  factory AdminInventoryCategoryOption.fromJson(Map<String, dynamic> json) {
    return AdminInventoryCategoryOption(
      value: '${json['value'] ?? ''}',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminInventoryFilters {
  const AdminInventoryFilters({
    this.branches = const <AdminInventoryBranchOption>[],
    this.categories = const <AdminInventoryCategoryOption>[],
  });

  static const empty = AdminInventoryFilters();

  final List<AdminInventoryBranchOption> branches;
  final List<AdminInventoryCategoryOption> categories;

  bool get hasBranches => branches.isNotEmpty;
  bool get hasCategories => categories.isNotEmpty;

  AdminInventoryBranchOption? branchById(String? id) {
    if (id == null) return null;
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  factory AdminInventoryFilters.fromJson(Map<String, dynamic> json) {
    final branches = json['branches'];
    final categories = json['categories'];
    return AdminInventoryFilters(
      branches: branches is List
          ? branches
                .whereType<Map>()
                .map(
                  (row) => AdminInventoryBranchOption.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminInventoryBranchOption>[],
      categories: categories is List
          ? categories
                .whereType<Map>()
                .map(
                  (row) => AdminInventoryCategoryOption.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminInventoryCategoryOption>[],
    );
  }
}
