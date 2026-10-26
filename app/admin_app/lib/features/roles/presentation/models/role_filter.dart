import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';

enum RoleFilter { all, system, custom }

extension RoleFilterView on RoleFilter {
  String get label => switch (this) {
    RoleFilter.all => S.rolesFilterAll,
    RoleFilter.system => S.rolesFilterSystem,
    RoleFilter.custom => S.rolesFilterCustom,
  };

  bool matches(AdminRole role) => switch (this) {
    RoleFilter.all => true,
    RoleFilter.system => role.isSystem,
    RoleFilter.custom => !role.isSystem,
  };
}

/// The roles whose name, code, type or permission holds [search], and that
/// belong to [filter].
List<AdminRole> filterRoles(
  List<AdminRole> roles, {
  String search = '',
  RoleFilter filter = RoleFilter.all,
}) {
  final query = search.trim().toLowerCase();
  final isArabic = AppLocale.instance.isArabic;
  return roles
      .where((role) {
        if (!filter.matches(role)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          role.code,
          role.nameAr ?? '',
          role.nameEn ?? '',
          roleDisplayName(role),
          roleTypeLabel(role),
          ...role.permissions,
          ...role.permissions.map(
            (code) => permissionName(code, isArabic: isArabic),
          ),
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}
