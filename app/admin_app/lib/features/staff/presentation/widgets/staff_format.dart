import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/core/utils/role_name.dart';
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
          AppColor.statusAmber,
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

/// كيف تُعرض حالة دعوة: اسمها ولونها.
///
/// `pending` و`accepted` و`cancelled` ما خزّنته القاعدة، و`expired` يضيفه
/// `admin_staff_invitations()` حين يتجاوز الأجل، فلا تحسب الشاشة ساعة المقارنة.
class StaffInvitationStatusView {
  const StaffInvitationStatusView(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;

  static StaffInvitationStatusView of(String code) {
    switch (code) {
      case 'pending':
        return StaffInvitationStatusView(
          code,
          S.staffInvitationPending,
          AppColor.statusAmber,
        );
      case 'accepted':
        return StaffInvitationStatusView(
          code,
          S.staffInvitationAccepted,
          AppColor.primaryColor,
        );
      case 'cancelled':
        return StaffInvitationStatusView(
          code,
          S.staffInvitationCancelled,
          AppColor.greyColor,
        );
      case 'expired':
        return StaffInvitationStatusView(
          code,
          S.staffInvitationExpired,
          AppColor.errorColor,
        );
      default:
        return StaffInvitationStatusView(
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
  final names = roleNames(member.roles.map((role) => role.roleCode));
  return names.isEmpty ? S.staffNoRoles : names;
}
