import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// The people domain: customers, staff, permissions and the branches.
List<AdminDestination> get peopleDestinations => <AdminDestination>[
  AdminDestination(
    id: 'customers',
    label: S.customers,
    icon: AppIcons.userMultiple,
    searchHint: S.searchCustomersHint,
    permission: 'customers.read',
    section: S.sectionPeople,
    tables: <String>['identity.profiles'],
  ),
  AdminDestination(
    id: 'staff',
    label: S.staffLabel,
    icon: AppIcons.user,
    searchHint: S.searchStaffHint,
    permission: 'admin.staff.read',
    section: S.sectionPeople,
    tables: <String>['identity.staff_members', 'identity.staff_roles'],
  ),
  AdminDestination(
    id: 'roles',
    label: S.rolesAndPermissions,
    icon: AppIcons.passwordKey,
    searchHint: S.searchRolesHint,
    permission: 'admin.role.read',
    section: S.sectionPeople,
    tables: <String>[
      'identity.roles',
      'identity.permissions',
      'identity.role_permissions',
    ],
  ),
  AdminDestination(
    id: 'auditLog',
    label: S.auditLog,
    icon: AppIcons.clipboard,
    searchHint: S.searchAuditLogHint,
    permission: 'audit.read',
    section: S.sectionPeople,
    tables: <String>['identity.audit_log'],
  ),
  AdminDestination(
    id: 'branches',
    label: S.branches,
    icon: AppIcons.store01,
    searchHint: S.searchBranchesHint,
    permission: 'settings.write',
    section: S.sectionPeople,
    tables: <String>['core.branches', 'core.brands'],
  ),
];
