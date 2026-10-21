import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// The people domain: customers, staff, permissions and the branches.
List<AdminDestination> get peopleDestinations => <AdminDestination>[
  AdminDestination(
    id: 'customers',
    label: S.customers,
    icon: HugeIcons.strokeRoundedUserMultiple,
    searchHint: S.searchCustomersHint,
    permission: 'customers.read',
    section: S.sectionPeople,
    tables: <String>['identity.profiles'],
  ),
  AdminDestination(
    id: 'addresses',
    label: S.addresses,
    icon: HugeIcons.strokeRoundedLocation01,
    searchHint: S.searchAddressesHint,
    permission: 'customers.read',
    section: S.sectionPeople,
    tables: <String>['identity.customer_addresses'],
  ),
  AdminDestination(
    id: 'staff',
    label: S.staffLabel,
    icon: HugeIcons.strokeRoundedUser,
    searchHint: S.searchStaffHint,
    permission: 'admin.staff.read',
    section: S.sectionPeople,
    tables: <String>['identity.staff_members', 'identity.staff_roles'],
  ),
  AdminDestination(
    id: 'roles',
    label: S.rolesAndPermissions,
    icon: HugeIcons.strokeRoundedKey01,
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
    icon: HugeIcons.strokeRoundedClipboard,
    searchHint: S.searchAuditLogHint,
    permission: 'audit.read',
    section: S.sectionPeople,
    tables: <String>['identity.audit_log'],
  ),
  AdminDestination(
    id: 'branches',
    label: S.branches,
    icon: HugeIcons.strokeRoundedStore01,
    searchHint: S.searchBranchesHint,
    permission: 'settings.write',
    section: S.sectionPeople,
    tables: <String>['core.branches', 'core.brands'],
  ),
  AdminDestination(
    id: 'deliveryZones',
    label: S.deliveryZones,
    icon: HugeIcons.strokeRoundedPin,
    searchHint: S.searchDeliveryZonesHint,
    permission: 'settings.write',
    section: S.sectionPeople,
    tables: <String>['core.delivery_zones', 'core.delivery_zone_branches'],
  ),
];
