import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/data/repositories/admin_nav_repository.dart';
import 'package:admin_app/features/shell/presentation/manager/admin_nav_cubit.dart';

class _FakeNavRepository extends AdminNavRepository {
  _FakeNavRepository({this.counts = AdminNavCounts.empty});

  AdminNavCounts counts;
  bool failing = false;
  int loads = 0;

  /// Whether the last read was asked for the notifications counter, so a test
  /// can prove the sidebar does not ask an account that may not open the page.
  bool? lastWithNotifications;

  @override
  Future<AdminNavCounts> loadCounts({bool withNotifications = false}) async {
    loads++;
    lastWithNotifications = withNotifications;
    if (failing) throw StateError('offline');
    return counts;
  }
}

void main() {
  test('the counts are read from the json of the rpc', () {
    final counts = AdminNavCounts.fromJson(const <String, dynamic>{
      'unread_orders': 4,
      'unread_kitchen': '7',
    });

    expect(counts.unreadOrders, 4);
    expect(counts.unreadKitchen, 7);
    expect(counts.isEmpty, isFalse);
    expect(AdminNavCounts.fromJson(const <String, dynamic>{}).isEmpty, isTrue);
  });

  test('a counter of zero counts as nothing to show', () {
    final counts = AdminNavCounts.fromJson(const <String, dynamic>{
      'unread_orders': 0,
      'unread_kitchen': 0,
      'unread_notifications': 0,
    });

    expect(counts.isEmpty, isTrue);
    expect(counts, AdminNavCounts.empty);
  });

  test('the notifications counter rides beside the other two', () {
    final counts = AdminNavCounts.empty.copyWithUnreadNotifications(9);

    expect(counts.unreadNotifications, 9);
    expect(counts.isEmpty, isFalse);
    expect(
      const AdminNavCounts(
        unreadOrders: 2,
        unreadKitchen: 3,
      ).copyWithUnreadNotifications(4),
      const AdminNavCounts(
        unreadOrders: 2,
        unreadKitchen: 3,
        unreadNotifications: 4,
      ),
    );
  });

  test('nothing is polled when both pages are out of reach', () async {
    final repository = _FakeNavRepository();
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: false, watchKitchen: false);
    await Future<void>.delayed(Duration.zero);

    expect(repository.loads, 0);
    expect(cubit.state, AdminNavCounts.empty);
  });

  test('starting the watch fetches the waiting work', () async {
    final repository = _FakeNavRepository(
      counts: const AdminNavCounts(unreadOrders: 3, unreadKitchen: 2),
    );
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: true, watchKitchen: true);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.unreadOrders, 3);
    expect(cubit.state.unreadKitchen, 2);
  });

  test('a failed poll keeps the last numbers', () async {
    final repository = _FakeNavRepository(
      counts: const AdminNavCounts(unreadOrders: 5, unreadKitchen: 1),
    );
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: true, watchKitchen: true);
    await Future<void>.delayed(Duration.zero);

    repository.failing = true;
    await cubit.refresh();

    expect(cubit.state.unreadOrders, 5);
    expect(cubit.state.unreadKitchen, 1);
  });

  test('stopping the watch clears the badges', () async {
    final repository = _FakeNavRepository(
      counts: const AdminNavCounts(unreadOrders: 5),
    );
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: true, watchKitchen: false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.unreadOrders, 5);

    cubit.start(watchOrders: false, watchKitchen: false);

    expect(cubit.state, AdminNavCounts.empty);
  });

  test(
    'the notifications counter is asked only for an allowed account',
    () async {
      final repository = _FakeNavRepository(
        counts: const AdminNavCounts(unreadNotifications: 6),
      );
      final cubit = AdminNavCubit(repository: repository);
      addTearDown(cubit.close);

      cubit.start(watchOrders: true, watchKitchen: false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastWithNotifications, isFalse);

      cubit.start(
        watchOrders: true,
        watchKitchen: false,
        watchNotifications: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastWithNotifications, isTrue);
      expect(cubit.state.unreadNotifications, 6);

      // Watching notifications alone is watching something: an account that may
      // open only this page still gets its badge.
      cubit.start(
        watchOrders: false,
        watchKitchen: false,
        watchNotifications: true,
      );
      await cubit.refresh();
      expect(repository.lastWithNotifications, isTrue);
    },
  );
}
