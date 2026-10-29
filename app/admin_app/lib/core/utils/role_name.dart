import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';

/// The display name of a `role_codes` value.
///
/// The code is a database identifier, never copy, so every surface that names
/// a role must go through this one map.
String roleName(String code) {
  final normalized = code.trim();
  switch (normalized) {
    case 'owner':
      return S.owner;
    case 'manager':
      return S.roleManager;
    case 'branch_manager':
      return S.roleBranchManager;
    case 'cashier':
      return S.roleCashier;
  }
  if (normalized.isEmpty) return '';
  return normalized
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// The distinct localized names of [codes], joined the way the active
/// language joins a list.
String roleNames(Iterable<String> codes) {
  final names = codes
      .map(roleName)
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList(growable: false);
  return names.join(AppLocale.instance.isArabic ? '، ' : ', ');
}
