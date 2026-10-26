import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';

/// The name of the role in the active language, falling back to the other
/// language and then to a readable form of its code.
String roleDisplayName(AdminRole role) {
  final isArabic = AppLocale.instance.isArabic;
  final arabic = role.nameAr?.trim() ?? '';
  final english = role.nameEn?.trim() ?? '';
  if (isArabic && arabic.isNotEmpty) return arabic;
  if (!isArabic && english.isNotEmpty) return english;
  if (arabic.isNotEmpty) return arabic;
  if (english.isNotEmpty) return english;
  return humanizeRoleCode(role.code);
}

String humanizeRoleCode(String code) {
  final normalized = code.trim();
  if (normalized.isEmpty) return '—';
  return normalized
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String roleTypeLabel(AdminRole role) =>
    role.isSystem ? S.systemRole : S.roleCustom;

Color roleTypeColor(AdminRole role) =>
    role.isSystem ? AppColor.adminAccent : const Color(0xFF5F70A8);

String roleCode(AdminRole role) {
  final code = role.code.trim();
  return code.isEmpty ? '—' : code;
}

String rolesCount(int count) => localizeDigits('$count');

String rolePermissionCount(AdminRole role) =>
    localizeDigits(S.rolePermissionsCount(role.permissions.length));

/// The permissions granted to [role], shaped like the catalogue rows, so a
/// read-only viewer can see the full list without loading the whole catalogue.
List<Map<String, dynamic>> rolePermissionEntries(AdminRole role) => [
  for (final code in role.permissions.toSet())
    {
      'code': code,
      'name_ar': permissionName(code, isArabic: true),
      'name_en': permissionName(code, isArabic: false),
    },
];

/// The first few permission names, so the list shows what a role can do.
String rolePermissionPreview(AdminRole role) {
  if (role.permissions.isEmpty) return S.roleNoPermissions;
  final isArabic = AppLocale.instance.isArabic;
  final names = role.permissions
      .take(3)
      .map((code) => permissionName(code, isArabic: isArabic))
      .toList(growable: false);
  return names.join(isArabic ? '، ' : ', ');
}

int distinctPermissions(List<AdminRole> roles) =>
    roles.expand((role) => role.permissions).toSet().length;
