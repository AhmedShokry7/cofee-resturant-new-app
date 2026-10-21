import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/auth/data/models/admin_session.dart';

void main() {
  test('owner role is treated as having every permission', () {
    final session = AdminSession.fromJson(<String, dynamic>{
      'staff_id': 's1',
      'full_name': 'Owner',
      'email': 'owner@example.com',
      'status': 'active',
      'roles': [
        {'role_id': 'r1', 'role_code': 'owner', 'branch_id': null},
      ],
      'permissions': <dynamic>[],
      'can_manage_all_branches': true,
    });

    expect(session.isOwner, isTrue);
    expect(session.hasPermission('anything.at_all'), isTrue);
  });

  test('non-owner permissions are resolved from branch scopes', () {
    final session = AdminSession.fromJson(<String, dynamic>{
      'staff_id': 's2',
      'full_name': 'Manager',
      'email': 'manager@example.com',
      'status': 'active',
      'roles': [
        {'role_id': 'r2', 'role_code': 'branch_manager', 'branch_id': 'b1'},
      ],
      'permissions': [
        {
          'branch_id': 'b1',
          'permissions': ['orders.read', 'inventory.read'],
        },
      ],
      'can_manage_all_branches': false,
    });

    expect(session.isOwner, isFalse);
    expect(session.hasPermission('orders.read'), isTrue);
    expect(session.hasPermission('inventory.read'), isTrue);
    expect(session.hasPermission('admin.staff.read'), isFalse);
    expect(session.canManageAllBranches, isFalse);
  });

  test('fromRpc accepts a JSON string payload', () {
    final session = AdminSession.fromRpc(
      '{"staff_id":"s3","full_name":"Cashier","email":"c@example.com",'
      '"status":"active","roles":[],"permissions":[],'
      '"can_manage_all_branches":false}',
    );

    expect(session.staffId, 's3');
    expect(session.fullName, 'Cashier');
  });

  test('fromRpc rejects unexpected payloads', () {
    expect(() => AdminSession.fromRpc(42), throwsFormatException);
  });
}
