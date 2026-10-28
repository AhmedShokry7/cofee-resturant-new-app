import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/repositories/admin_order_repository.dart';
import 'package:admin_app/features/orders/data/services/order_realtime_feed.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';

class _FakeOrderRepository extends AdminOrderRepository {
  /// ما تحتفظ به القاعدة: الكتابة تُبدّل الصفوف كما يفعل الخادم فعلًا.
  List<AdminOrder> orders = <AdminOrder>[];
  Object? failure;
  int loads = 0;
  final List<String> statusWrites = <String>[];
  final List<String> itemWrites = <String>[];

  /// Held open so a second write can arrive while the first is still running.
  Completer<void>? gate;

  @override
  Future<List<AdminOrder>> loadOrders() async {
    loads += 1;
    if (failure != null) throw failure!;
    return orders;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    statusWrites.add('$orderId:$status');
    if (failure != null) throw failure!;
    await gate?.future;
  }

  @override
  Future<void> addOrderItem(
    String orderId,
    String productId,
    int quantity,
  ) async {
    itemWrites.add('$orderId:$productId:$quantity');
    if (failure != null) throw failure!;
    orders = <AdminOrder>[
      for (final order in orders)
        if (order.id == orderId)
          _order(id: order.id, grandTotal: order.grandTotal + 11)
        else
          order,
    ];
  }

  @override
  Future<void> removeOrderItem(String orderItemId) async {
    itemWrites.add(orderItemId);
    if (failure != null) throw failure!;
    orders = <AdminOrder>[
      for (final order in orders)
        _order(id: order.id, grandTotal: order.grandTotal - 11),
    ];
  }
}

class _FakeOrderFeed extends OrderRealtimeFeed {
  VoidCallback? _onChanged;
  int starts = 0;
  int disposes = 0;

  @override
  void start(VoidCallback onChanged) {
    starts += 1;
    _onChanged = onChanged;
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
    _onChanged = null;
  }

  void emitChange() => _onChanged?.call();
}

AdminOrder _order({
  String id = 'o1',
  String status = 'pending',
  double grandTotal = 20,
}) => AdminOrder(
  id: id,
  orderNumber: '1001',
  fulfillmentType: 'delivery',
  status: status,
  paymentStatus: 'unpaid',
  subtotal: 20,
  discountTotal: 0,
  deliveryFee: 0,
  taxTotal: 0,
  grandTotal: grandTotal,
  placedAt: DateTime(2026, 10, 20, 14, 30),
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('the directory write lock', () {
    test('a write that arrives while another runs is dropped', () async {
      final gate = Completer<void>();
      final repository = _FakeOrderRepository()..gate = gate;
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      final first = cubit.updateOrderStatus('o1', 'confirmed');
      final second = await cubit.updateOrderStatus('o1', 'cancelled');

      expect(second, isFalse);
      expect(repository.statusWrites, <String>['o1:confirmed']);

      gate.complete();
      expect(await first, isTrue);
    });

    test('a dropped write says so instead of pretending it landed', () async {
      final repository = _FakeOrderRepository();
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      final running = cubit.updateOrderStatus('o1', 'confirmed');
      final busy = cubit.state.saving;
      await running;

      expect(busy, isTrue);
      expect(cubit.state.saving, isFalse);
    });

    test('a failed write still releases the directory', () async {
      final repository = _FakeOrderRepository()
        ..failure = StateError('the branch is closed');
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      await expectLater(
        cubit.updateOrderStatus('o1', 'confirmed'),
        throwsStateError,
      );
      expect(cubit.state.saving, isFalse);

      repository.failure = null;
      expect(await cubit.updateOrderStatus('o1', 'confirmed'), isTrue);
      expect(repository.statusWrites, <String>['o1:confirmed', 'o1:confirmed']);
    });

    test('a status write reloads the rows it just changed', () async {
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order(status: 'confirmed')];
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      final loadsBefore = repository.loads;

      await cubit.updateOrderStatus('o1', 'confirmed');

      expect(repository.loads, greaterThan(loadsBefore));
      expect(cubit.state.orders.single.status, 'confirmed');
    });

    test(
      'an item write refreshes the row the detail screen reads back',
      () async {
        final repository = _FakeOrderRepository()
          ..orders = <AdminOrder>[_order()];
        final cubit = AdminOrderCubit(repository: repository);
        addTearDown(cubit.close);
        await cubit.load();

        // الشاشة تعرض ما ترجعه `findOrder`، وهي تجيب من هذا المخزن أولًا: كتابة
        // بلا إعادة قراءة تُظهر الطلب كما كان قبل أن يعدّله الموظف.
        expect(await cubit.addOrderItem('o1', 'p1', 1), isTrue);
        expect((await cubit.findOrder('o1'))?.grandTotal, 31);

        expect(await cubit.removeOrderItem('i1'), isTrue);
        expect((await cubit.findOrder('o1'))?.grandTotal, 20);
      },
    );
  });

  group('the quiet reload', () {
    test('keeps the rows on screen when the read fails', () async {
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order()];
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();

      repository.failure = StateError('offline');
      await cubit.refreshLive();

      expect(cubit.state.status, AdminOrderStatus.ready);
      expect(cubit.state.orders, hasLength(1));
      expect(cubit.state.orders.single.id, 'o1');
      expect(cubit.state.errorMessage, S.ordersLoadFailed);
    });

    test('clears the error once the rows come back', () async {
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order()];
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      repository.failure = StateError('offline');
      await cubit.refreshLive();

      repository.failure = null;
      await cubit.refreshLive();

      expect(cubit.state.errorMessage, isNull);
    });

    test('one live event asks the repository once', () async {
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order()];
      final feed = _FakeOrderFeed();
      final cubit = AdminOrderCubit(repository: repository, realtimeFeed: feed);
      addTearDown(cubit.close);

      cubit.startLiveUpdates();
      final loadsAfterStart = repository.loads;

      feed.emitChange();
      await cubit.refreshLive();

      expect(feed.starts, 1);
      expect(repository.loads, greaterThan(loadsAfterStart));
    });

    test('starts once, however many screens ask', () async {
      final feed = _FakeOrderFeed();
      final cubit = AdminOrderCubit(
        repository: _FakeOrderRepository(),
        realtimeFeed: feed,
      );

      cubit.startLiveUpdates();
      cubit.startLiveUpdates();
      await cubit.close();

      expect(feed.starts, 1);
      expect(feed.disposes, 1);
    });
  });
}
