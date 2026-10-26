import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';

/// How one staff status is shown: its localized name and colour.
///
/// The stored values of `identity.staff.status` are `invited`, `active` and
/// `suspended`.
class StaffStatusView {
  const StaffStatusView(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static StaffStatusView of(String code) {
    switch (code) {
      case 'active':
        return StaffStatusView(code, S.activeStatus, AppColor.primaryColor);
      case 'invited':
        return StaffStatusView(
          code,
          S.staffStatusInvited,
          const Color(0xFFF59E0B),
        );
      case 'suspended':
        return StaffStatusView(
          code,
          S.staffStatusSuspended,
          AppColor.errorColor,
        );
      default:
        return StaffStatusView(
          code,
          code.trim().isEmpty ? '—' : code,
          AppColor.greyColor,
        );
    }
  }
}

String staffDisplayName(AdminStaffMember member) => member.displayName();

String? staffContactLine(AdminStaffMember member) {
  final name = staffDisplayName(member);
  final email = member.email?.trim() ?? '';
  if (email.isNotEmpty && email != name) return email;
  return null;
}

String staffInitials(AdminStaffMember member) =>
    initialsOf(staffDisplayName(member));

String staffMembersCount(int count) => localizeDigits('$count');

String staffJoined(AdminStaffMember member) =>
    localizedDate(member.acceptedAt ?? member.createdAt);

String staffPermissionsCount(AdminStaffMember member) =>
    localizeDigits(S.staffPermissionsCount(member.permissions.length));

/// The names of the roles the member holds, in their display language.
String staffRolesText(AdminStaffMember member) {
  final names = member.roles
      .map((role) => staffRoleName(role.roleCode))
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) return S.staffNoRoles;
  return names.join(AppLocale.instance.isArabic ? '، ' : ', ');
}

String staffRoleName(String code) {
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
