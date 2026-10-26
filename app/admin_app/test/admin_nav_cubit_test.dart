import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/data/repositories/admin_nav_repository.dart';
import 'package:admin_app/features/shell/presentation/manager/admin_nav_cubit.dart';

class _FakeNavRepository extends AdminNavRepository {
  _FakeNavRepository({this.counts = AdminNavCounts.empty});

  AdminNavCounts counts;
  bool failing = false;
  int loads = 0;

  @override
  Future<AdminNavCounts> loadCounts() async {
    loads++;
    if (failing) throw StateError('offline');
    return counts;
  }
}

void main() {
  test('the counts are read from the json of the rpc', () {
    final counts = AdminNavCounts.fromJson(const <String, dynamic>{
      'new_orders': 4,
      'kitchen_queue': '7',
    });

    expect(counts.newOrders, 4);
    expect(counts.kitchenQueue, 7);
    expect(counts.isEmpty, isFalse);
    expect(AdminNavCounts.fromJson(const <String, dynamic>{}).isEmpty, isTrue);
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
      counts: const AdminNavCounts(newOrders: 3, kitchenQueue: 2),
    );
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: true, watchKitchen: true);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.newOrders, 3);
    expect(cubit.state.kitchenQueue, 2);
  });

  test('a failed poll keeps the last numbers', () async {
    final repository = _FakeNavRepository(
      counts: const AdminNavCounts(newOrders: 5, kitchenQueue: 1),
    );
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: true, watchKitchen: true);
    await Future<void>.delayed(Duration.zero);

    repository.failing = true;
    await cubit.refresh();

    expect(cubit.state.newOrders, 5);
    expect(cubit.state.kitchenQueue, 1);
  });

  test('stopping the watch clears the badges', () async {
    final repository = _FakeNavRepository(
      counts: const AdminNavCounts(newOrders: 5),
    );
    final cubit = AdminNavCubit(repository: repository);
    addTearDown(cubit.close);

    cubit.start(watchOrders: true, watchKitchen: false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.newOrders, 5);

    cubit.start(watchOrders: false, watchKitchen: false);

    expect(cubit.state, AdminNavCounts.empty);
  });
}
