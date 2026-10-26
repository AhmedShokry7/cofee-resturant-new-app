import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/locale/permission_catalog.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/presentation/models/role_filter.dart';
import 'package:admin_app/features/roles/presentation/widgets/role_format.dart';

const _roles = <AdminRole>[
  AdminRole(
    id: '1',
    code: 'manager',
    nameAr: 'مدير عام',
    nameEn: 'Manager',
    isSystem: true,
    permissions: ['orders.read', 'payments.read'],
  ),
  AdminRole(
    id: '2',
    code: 'cashier',
    nameAr: 'كاشير',
    nameEn: 'Cashier',
    isSystem: true,
    permissions: ['orders.read'],
  ),
  AdminRole(id: '3', code: 'shift_leader', isSystem: false, permissions: []),
];

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('role filter', () {
    test('separates system from custom roles', () {
      expect(
        filterRoles(
          _roles,
          filter: RoleFilter.system,
        ).map((role) => role.id).toList(),
        ['1', '2'],
      );
      expect(
        filterRoles(
          _roles,
          filter: RoleFilter.custom,
        ).map((role) => role.id).toList(),
        ['3'],
      );
    });

    test('searches the code, name and permission names', () {
      expect(filterRoles(_roles, search: 'manager').single.id, '1');
      expect(filterRoles(_roles, search: 'cash').single.id, '2');
      expect(filterRoles(_roles, search: 'view payments').single.id, '1');
      expect(filterRoles(_roles, search: 'shift leader').single.id, '3');
    });

    test('searches the Arabic name in Arabic', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);

      expect(filterRoles(_roles, search: 'مدير عام').single.id, '1');
      expect(filterRoles(_roles, search: 'عرض المدفوعات').single.id, '1');
    });
  });

  group('role format', () {
    test('picks the name of the active language', () {
      expect(roleDisplayName(_roles[0]), 'Manager');
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(roleDisplayName(_roles[0]), 'مدير عام');
    });

    test('falls back to a readable code', () {
      expect(roleDisplayName(_roles[2]), 'Shift Leader');
      expect(humanizeRoleCode(''), '—');
    });

    test('labels the type of the role', () {
      expect(roleTypeLabel(_roles[0]), S.systemRole);
      expect(roleTypeLabel(_roles[2]), S.roleCustom);
    });

    test('summarises the granted permissions', () {
      expect(rolePermissionCount(_roles[0]), '2 permissions');
      expect(
        rolePermissionPreview(_roles[0]),
        '${permissionName('orders.read', isArabic: false)}, '
        '${permissionName('payments.read', isArabic: false)}',
      );
      expect(rolePermissionPreview(_roles[2]), S.roleNoPermissions);
      expect(distinctPermissions(_roles), 2);

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(rolePermissionCount(_roles[0]), '٢ صلاحيات');
    });

    test('builds a read-only catalogue from the granted permissions', () {
      final entries = rolePermissionEntries(_roles[0]);
      expect(entries.map((entry) => entry['code']).toList(), [
        'orders.read',
        'payments.read',
      ]);
      expect(
        entries.first['name_en'],
        permissionName('orders.read', isArabic: false),
      );
      expect(
        entries.first['name_ar'],
        permissionName('orders.read', isArabic: true),
      );
      expect(rolePermissionEntries(_roles[2]), isEmpty);
    });
  });
}
