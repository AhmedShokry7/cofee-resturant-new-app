import 'package:admin_app/core/auth/admin_permission_scope.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_operational_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/stub_supabase_client.dart';

void main() {
  group('admin assistant operational reads', () {
    test('strips all non-aggregate order fields from returned data', () {
      final safe = AdminAssistantOperationalReadRepository.sanitizeOrderMetrics(
        {
          'from': '2026-01-01T00:00:00Z',
          'until': '2026-01-31T00:00:00Z',
          'orders': 8,
          'status_counts': [
            {'status': 'completed', 'orders': 5, 'customer_name': 'Private'},
          ],
          'branch_comparison': [
            {
              'branch_name_ar': 'فرع تجريبي',
              'orders': 8,
              'phone': '0500000000',
            },
          ],
          'recent_orders': [
            {'customer_name': 'Private'},
          ],
        },
      );

      expect(safe['orders'], 8);
      expect(safe.containsKey('recent_orders'), isFalse);
      expect(safe['status_counts'], [
        {'status': 'completed', 'orders': 5},
      ]);
      expect(safe['branch_comparison'], [
        {'branch_name_ar': 'فرع تجريبي', 'orders': 8},
      ]);
      expect(safe.toString(), isNot(contains('Private')));
      expect(safe.toString(), isNot(contains('0500000000')));
    });

    test(
      'strips customer and card details from payment aggregate payloads',
      () {
        final safe =
            AdminAssistantOperationalReadRepository.sanitizePaymentMetrics({
              'transactions': 3,
              'captured_by_currency': [
                {
                  'currency_code': 'SAR',
                  'captured_transactions': 2,
                  'captured_transaction_amount': 40.0,
                  'card_last4': '1234',
                  'customer_name': 'Private',
                },
              ],
              'methods': [
                {
                  'method_code': 'card',
                  'transactions': 2,
                  'card_holder_name': 'Private',
                },
              ],
              'provider_reference': 'secret-reference',
            });

        expect(safe['transactions'], 3);
        expect(safe['captured_by_currency'], [
          {
            'currency_code': 'SAR',
            'captured_transactions': 2,
            'captured_transaction_amount': 40.0,
          },
        ]);
        expect(safe['methods'], [
          {'method_code': 'card', 'transactions': 2},
        ]);
        expect(safe.toString(), isNot(contains('1234')));
        expect(safe.toString(), isNot(contains('Private')));
        expect(safe.toString(), isNot(contains('secret-reference')));
      },
    );

    test(
      'does not call Supabase when the session lacks the read permission',
      () async {
        final client = StubSupabaseClient(payload: const <String, dynamic>{});
        final repository = AdminAssistantOperationalReadRepository(
          client: client,
          session: _session(const ['orders.read']),
        );

        final result = await repository.loadPayments();

        expect(
          result.status,
          AdminAssistantOperationalReadStatus.permissionDenied,
        );
        expect(result.data, isEmpty);
      },
    );

    test(
      'uses distinct permission gates for orders, payments, tables, and stock',
      () async {
        final client = StubSupabaseFunctions(
          responses: const {
            'admin_assistant_order_metrics': {'orders': 4},
            'admin_assistant_payment_metrics': {
              'transactions': 0,
              'methods': <Map<String, Object?>>[],
              'captured_by_currency': <Map<String, Object?>>[],
            },
            'admin_assistant_dining_summary': {
              'branch': {'name_ar': 'فرع الاختبار', 'id': 'private-id'},
              'metrics': {
                'tables': 3,
                'available': 2,
                'customer_phone': '0500',
              },
              'table_status_counts': [
                {'status': 'available', 'tables': 2, 'table_id': 'private-id'},
              ],
            },
            'admin_stock_movement_metrics': {
              'total': 7,
              'waste': 1,
              'actor_name': 'Private Staff',
            },
          },
        );
        final repository = AdminAssistantOperationalReadRepository(
          client: client,
          session: _session(const [
            'orders.read',
            'tables.read',
            'inventory.read',
          ]),
        );

        final orders = await repository.loadOrders();
        final payments = await repository.loadPayments();
        final dining = await repository.loadDining();
        final inventory = await repository.loadInventoryMovements();

        expect(orders.status, AdminAssistantOperationalReadStatus.ready);
        expect(orders.data['orders'], 4);
        expect(
          payments.status,
          AdminAssistantOperationalReadStatus.permissionDenied,
        );
        expect(dining.status, AdminAssistantOperationalReadStatus.ready);
        expect(dining.data['branch'], {'name_ar': 'فرع الاختبار'});
        expect(dining.data['metrics'], {'tables': 3, 'available': 2});
        expect(inventory.status, AdminAssistantOperationalReadStatus.ready);
        expect(inventory.data, {'total': 7, 'waste': 1});
        expect(client.events.last, 'rpc:admin_stock_movement_metrics');
        expect(
          client.params['admin_assistant_order_metrics']?['p_from'],
          isNull,
        );
      },
    );
  });
}

AdminSession _session(List<String> permissions) => AdminSession(
  staffId: 'test-staff',
  fullName: 'Test Staff',
  email: 'test@example.local',
  status: 'active',
  roles: const [],
  permissionScopes: [
    AdminPermissionScope(branchId: 'test-branch', permissions: permissions),
  ],
  canManageAllBranches: false,
);
