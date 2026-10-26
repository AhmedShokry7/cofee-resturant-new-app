import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/models/staff_filter.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';

AdminStaffMember _member({
  required String id,
  required String name,
  required String email,
  required String status,
  List<String> roles = const <String>['manager'],
  List<String> permissions = const <String>[],
  DateTime? createdAt,
}) => AdminStaffMember(
  id: id,
  userId: 'u-$id',
  fullName: name,
  email: email,
  status: status,
  createdAt: createdAt ?? DateTime(2026, 1, 2),
  roles: [
    for (final code in roles) AdminStaffRole(roleId: 'r-$code', roleCode: code),
  ],
  permissions: permissions,
);

final _staff = <AdminStaffMember>[
  _member(
    id: '1',
    name: 'Sara Hassan',
    email: 'sara@example.com',
    status: 'active',
    roles: ['manager'],
    permissions: ['orders.read', 'payments.read'],
  ),
  _member(
    id: '2',
    name: 'Omar Ali',
    email: 'omar@example.com',
    status: 'invited',
    roles: ['cashier'],
    permissions: ['orders.read'],
  ),
  _member(
    id: '3',
    name: 'Nour Adel',
    email: 'nour@example.com',
    status: 'suspended',
    roles: ['branch_manager'],
  ),
];

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('staff filter', () {
    test('keeps every member for the all filter', () {
      expect(
        filterStaff(
          _staff,
          filter: StaffFilter.all,
        ).map((member) => member.id).toList(),
        ['1', '2', '3'],
      );
    });

    test('matches the stored status', () {
      expect(
        filterStaff(
          _staff,
          filter: StaffFilter.active,
        ).map((member) => member.id).toList(),
        ['1'],
      );
      expect(
        filterStaff(
          _staff,
          filter: StaffFilter.invited,
        ).map((member) => member.id).toList(),
        ['2'],
      );
      expect(
        filterStaff(
          _staff,
          filter: StaffFilter.suspended,
        ).map((member) => member.id).toList(),
        ['3'],
      );
    });

    test('searches the name, email, role and permission names', () {
      expect(filterStaff(_staff, search: 'sara').single.id, '1');
      expect(filterStaff(_staff, search: 'omar@').single.id, '2');
      expect(filterStaff(_staff, search: 'branch manager').single.id, '3');
      expect(filterStaff(_staff, search: 'view payments').single.id, '1');
    });

    test('searches in Arabic and matches the localized role name', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);

      expect(filterStaff(_staff, search: 'مدير فرع').single.id, '3');
      expect(filterStaff(_staff, search: 'عرض المدفوعات').single.id, '1');
    });

    test('combines the status filter with the search', () {
      expect(
        filterStaff(
          _staff,
          search: 'example.com',
          filter: StaffFilter.active,
        ).single.id,
        '1',
      );
      expect(
        filterStaff(_staff, search: 'sara', filter: StaffFilter.suspended),
        isEmpty,
      );
    });
  });

  group('staff format', () {
    test('names the built-in roles in the active language', () {
      expect(staffRoleName('owner'), S.owner);
      expect(staffRoleName('manager'), S.roleManager);
      expect(staffRoleName('branch_manager'), S.roleBranchManager);
      expect(staffRoleName('cashier'), S.roleCashier);
      expect(staffRoleName('shift_leader'), 'Shift Leader');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(staffRoleName('owner'), S.owner);
      expect(staffRoleName('manager'), S.roleManager);
    });

    test('joins the roles or says the member has none', () {
      expect(staffRolesText(_staff[2]), S.roleBranchManager);
      expect(staffRolesText(_staff[0]), S.roleManager);

      final withoutRoles = _member(
        id: '4',
        name: 'Hala',
        email: 'hala@example.com',
        status: 'invited',
        roles: const <String>[],
      );
      expect(staffRolesText(withoutRoles), S.staffNoRoles);
    });

    test('localizes the permission count and the joined date', () {
      expect(staffPermissionsCount(_staff[0]), '2 permissions');
      expect(staffJoined(_staff[0]), '2 Jan 2026');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(staffPermissionsCount(_staff[0]), '٢ صلاحيات');
      expect(staffJoined(_staff[0]), '٢ يناير ٢٠٢٦');
    });

    test('builds initials from the display name', () {
      expect(staffInitials(_staff[0]), 'SH');
      expect(staffInitials(_staff[1]), 'OA');
    });

    test('shows a localized status or the raw unknown one', () {
      expect(StaffStatusView.of('active').label, S.activeStatus);
      expect(StaffStatusView.of('invited').label, S.staffStatusInvited);
      expect(StaffStatusView.of('suspended').label, S.staffStatusSuspended);
      expect(StaffStatusView.of('on_leave').label, 'on_leave');
    });
  });
}
