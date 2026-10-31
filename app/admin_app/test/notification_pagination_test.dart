import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_state.dart';

import 'helpers/stub_supabase_client.dart';

void main() {
  test(
    'every request states the page size, so the SQL default never applies',
    () async {
      final client = StubSupabaseFunctions(
        responses: const <String, Object?>{
          'admin_notifications': <String, dynamic>{
            'total': 25,
            'rows': <dynamic>[],
          },
        },
      );
      final repository = AdminNotificationsRepository(client);

      await repository.loadNotifications(page: 2);

      final params = client.params['admin_notifications']!;
      expect(params['p_limit'], AdminNotificationsPaging.pageSize);
      expect(params['p_offset'], 2 * AdminNotificationsPaging.pageSize);
    },
  );

  test(
    'the page size the directory counts with is the one it asks for',
    () async {
      final client = StubSupabaseFunctions(
        responses: const <String, Object?>{
          'admin_notifications': <String, dynamic>{
            'total': 25,
            'rows': <dynamic>[],
          },
        },
      );
      final repository = AdminNotificationsRepository(client);
      const state = AdminNotificationsState(total: 25);

      await repository.loadNotifications(page: state.pages - 1);

      final params = client.params['admin_notifications']!;
      expect(state.pageSize, AdminNotificationsPaging.pageSize);
      expect(state.pages, 3);
      expect(params['p_offset'], (state.pages - 1) * params['p_limit']);
    },
  );

  test('the page size stays inside what admin_notifications accepts', () {
    // `v_limit = least(greatest(coalesce(p_limit, 20), 1), 100)` in SQL: a page
    // size outside that range would silently disagree with the Dart count.
    expect(AdminNotificationsPaging.pageSize, inInclusiveRange(1, 100));
  });
}
