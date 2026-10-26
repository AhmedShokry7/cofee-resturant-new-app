import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';

enum StaffFilter { all, active, invited, suspended }

extension StaffFilterView on StaffFilter {
  String get label => switch (this) {
    StaffFilter.all => S.staffFilterAll,
    StaffFilter.active => S.staffFilterActive,
    StaffFilter.invited => S.staffFilterInvited,
    StaffFilter.suspended => S.staffFilterSuspended,
  };

  bool matches(AdminStaffMember member) => switch (this) {
    StaffFilter.all => true,
    StaffFilter.active => member.status == 'active',
    StaffFilter.invited => member.status == 'invited',
    StaffFilter.suspended => member.status == 'suspended',
  };
}

/// The staff members whose name, email, role, permission or status holds
/// [search], and who belong to [filter].
List<AdminStaffMember> filterStaff(
  List<AdminStaffMember> staff, {
  String search = '',
  StaffFilter filter = StaffFilter.all,
}) {
  final query = search.trim().toLowerCase();
  final isArabic = AppLocale.instance.isArabic;
  return staff
      .where((member) {
        if (!filter.matches(member)) return false;
        if (query.isEmpty) return true;
        final text = <String>[
          member.fullName ?? '',
          member.email ?? '',
          ...member.roles.map((role) => role.roleCode),
          ...member.roles.map((role) => staffRoleName(role.roleCode)),
          ...member.permissions,
          ...member.permissions.map(
            (code) => permissionName(code, isArabic: isArabic),
          ),
          StaffStatusView.of(member.status).label,
        ].join(' ').toLowerCase();
        return text.contains(query);
      })
      .toList(growable: false);
}
