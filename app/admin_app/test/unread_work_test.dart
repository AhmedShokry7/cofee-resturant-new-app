import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/services/postgres_changes_feed.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/kitchen/data/repositories/admin_kitchen_repository.dart';
import 'package:admin_app/features/kitchen/data/services/kitchen_realtime_feed.dart';
import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/presentation/manager/admin_kitchen_cubit.dart';
import 'package:admin_app/features/orders/data/repositories/admin_order_repository.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/pages/order_detail_page.dart';
import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/data/repositories/admin_nav_repository.dart';
import 'package:admin_app/features/shell/presentation/manager/admin_nav_cubit.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destinations.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar_item.dart';

class _FakeNavRepository extends AdminNavRepository {
  _FakeNavRepository(this.counts);

  AdminNavCounts counts;
  bool failing = false;
  int loads = 0;

  @override
  Future<AdminNavCounts> loadCounts() async {
    loads += 1;
    if (failing) throw StateError('the counters are unreachable');
    return counts;
  }
}

class _FakeFeed extends PostgresChangesFeed {
  _FakeFeed()
    : super(
        channelPrefix: 'test-feed',
        tables: const <RealtimeTable>[RealtimeTable('orders', 'orders')],
      );

  VoidCallback? _handler;
  int starts = 0;
  int disposes = 0;

  @override
  void start(VoidCallback onChanged) {
    starts += 1;
    _handler = onChanged;
  }

  @override
  Future<void> dispose() async {
    disposes += 1;
    _handler = null;
  }

  void emitChange() => _handler?.call();
}

class _FakeOrderRepository extends AdminOrderRepository {
  List<AdminOrder> orders = <AdminOrder>[];
  final List<String> viewed = <String>[];
  final List<String> statusChanges = <String>[];
  bool failView = false;

  @override
  Future<List<AdminOrder>> loadOrders() async => orders;

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    statusChanges.add(orderId);
  }

  @override
  Future<void> markOrderViewed(String orderId) async {
    if (failView) throw StateError('stamp failed');
    viewed.add(orderId);
  }
}

class _FakeKitchenRepository extends AdminKitchenRepository {
  List<AdminKitchenTicket> tickets = <AdminKitchenTicket>[];
  bool failBoard = false;
  final List<List<String>> viewedBatches = <List<String>>[];

  @override
  Future<AdminKitchenBoard> loadBoard({
    String? search,
    String? branchId,
    int limit = 150,
  }) async {
    if (failBoard) throw StateError('board failed');
    return AdminKitchenBoard(tickets: tickets, total: tickets.length);
  }

  @override
  Future<void> markTicketsViewed(List<String> ticketIds) async {
    viewedBatches.add(List<String>.of(ticketIds));
  }
}

class _SilentKitchenFeed extends KitchenRealtimeFeed {
  @override
  void start(VoidCallback onChanged) {}

  @override
  Future<void> dispose() async {}
}

AdminOrder _order({String id = 'o1', String status = 'pending'}) => AdminOrder(
  id: id,
  orderNumber: '1001',
  fulfillmentType: 'delivery',
  status: status,
  paymentStatus: 'unpaid',
  subtotal: 20,
  discountTotal: 0,
  deliveryFee: 0,
  taxTotal: 0,
  grandTotal: 20,
  placedAt: DateTime(2026, 10, 20, 14, 30),
);

AdminKitchenTicket _ticket(String id, KitchenTicketStatus status) =>
    AdminKitchenTicket(
      id: id,
      orderId: 'o-$id',
      orderNumber: '#$id',
      placedAt: DateTime(2026, 10, 20, 14, 30),
      branchId: 'b1',
      status: status,
    );

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('the sidebar counters', () {
    test(
      'are re-read, never incremented, when the feed repeats an event',
      () async {
        final repository = _FakeNavRepository(
          const AdminNavCounts(unreadOrders: 2, unreadKitchen: 1),
        );
        final feed = _FakeFeed();
        final cubit = AdminNavCubit(
          repository: repository,
          liveFeed: ({required bool watchOrders, required bool watchKitchen}) =>
              feed,
          refreshInterval: const Duration(days: 1),
        );
        addTearDown(cubit.close);

        cubit.start(watchOrders: true, watchKitchen: true);
        await Future<void>.delayed(Duration.zero);
        final loadsAfterStart = repository.loads;

        feed.emitChange();
        feed.emitChange();
        await Future<void>.delayed(Duration.zero);

        expect(repository.loads, greaterThan(loadsAfterStart));
        expect(
          cubit.state,
          const AdminNavCounts(unreadOrders: 2, unreadKitchen: 1),
        );
      },
    );

    test('a new ticket moves only the kitchen number', () async {
      final repository = _FakeNavRepository(
        const AdminNavCounts(unreadOrders: 2, unreadKitchen: 1),
      );
      final feed = _FakeFeed();
      final cubit = AdminNavCubit(
        repository: repository,
        liveFeed: ({required bool watchOrders, required bool watchKitchen}) =>
            feed,
        refreshInterval: const Duration(days: 1),
      );
      addTearDown(cubit.close);

      cubit.start(watchOrders: true, watchKitchen: true);
      await Future<void>.delayed(Duration.zero);

      repository.counts = const AdminNavCounts(
        unreadOrders: 2,
        unreadKitchen: 2,
      );
      feed.emitChange();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.unreadOrders, 2);
      expect(cubit.state.unreadKitchen, 2);
    });

    test('opens one channel and closes it with the cubit', () async {
      final feed = _FakeFeed();
      final cubit = AdminNavCubit(
        repository: _FakeNavRepository(AdminNavCounts.empty),
        liveFeed: ({required bool watchOrders, required bool watchKitchen}) =>
            feed,
      );

      cubit.start(watchOrders: true, watchKitchen: false);
      cubit.start(watchOrders: true, watchKitchen: false);
      expect(feed.starts, 1);

      await cubit.close();
      expect(feed.disposes, 1);
    });

    test('watches only the sections the staff member may open', () async {
      final watched = <String, bool>{};
      final cubit = AdminNavCubit(
        repository: _FakeNavRepository(AdminNavCounts.empty),
        liveFeed: ({required bool watchOrders, required bool watchKitchen}) {
          watched['orders'] = watchOrders;
          watched['kitchen'] = watchKitchen;
          return _FakeFeed();
        },
      );
      addTearDown(cubit.close);

      cubit.start(watchOrders: false, watchKitchen: true);
      expect(watched, <String, bool>{'orders': false, 'kitchen': true});
    });

    test('shows nothing and opens nothing without either page', () async {
      var built = 0;
      final cubit = AdminNavCubit(
        repository: _FakeNavRepository(
          const AdminNavCounts(unreadOrders: 5, unreadKitchen: 5),
        ),
        liveFeed: ({required bool watchOrders, required bool watchKitchen}) {
          built += 1;
          return _FakeFeed();
        },
      );
      addTearDown(cubit.close);

      cubit.start(watchOrders: false, watchKitchen: false);
      await Future<void>.delayed(Duration.zero);

      expect(built, 0);
      expect(cubit.state, AdminNavCounts.empty);
    });
  });

  group('the sidebar badge', () {
    testWidgets('is a red pill with white text and hides at zero', (
      tester,
    ) async {
      _setViewport(tester, const Size(1280, 900));
      final destination = adminDestinations.firstWhere(
        (item) => item.id == 'orders',
      );

      Widget row(int? count) => MaterialApp(
        home: Scaffold(
          body: AdminSidebarItem(
            destination: destination,
            isSelected: false,
            badgeCount: count,
            onTap: () {},
          ),
        ),
      );

      await tester.pumpWidget(row(3));

      final label = find.text(localizeDigits('3'));
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).style?.color, AppColor.whiteColor);
      final badge = tester.widget<Container>(
        find.ancestor(of: label, matching: find.byType(Container)).last,
      );
      expect((badge.decoration as BoxDecoration?)?.color, AppColor.errorColor);

      await tester.pumpWidget(row(null));
      expect(find.text(localizeDigits('0')), findsNothing);
    });
  });

  group('opening an order', () {
    test('stamps it read without touching its status', () async {
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order()];
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.markOrderViewed('o1');

      expect(repository.viewed, <String>['o1']);
      expect(repository.statusChanges, isEmpty);
    });

    test('a status change alone never stamps', () async {
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order(status: 'confirmed')];
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.updateOrderStatus('o1', 'confirmed');

      expect(repository.statusChanges, <String>['o1']);
      expect(repository.viewed, isEmpty);
    });

    test('a failed stamp leaves the page working', () async {
      final repository = _FakeOrderRepository()..failView = true;
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.markOrderViewed('o1');

      expect(repository.viewed, isEmpty);
    });

    testWidgets('the detail page stamps the order it shows', (tester) async {
      _setViewport(tester, const Size(1280, 1400));
      final repository = _FakeOrderRepository()
        ..orders = <AdminOrder>[_order()];
      final cubit = AdminOrderCubit(repository: repository);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailsPage(order: _order(), cubit: cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.viewed, <String>['o1']);
      expect(tester.takeException(), isNull);
    });
  });

  group('the kitchen board', () {
    test('stamps only the tickets it showed that are still work', () async {
      final repository = _FakeKitchenRepository()
        ..tickets = <AdminKitchenTicket>[
          _ticket('t1', KitchenTicketStatus.queued),
          _ticket('t2', KitchenTicketStatus.preparing),
          _ticket('t3', KitchenTicketStatus.completed),
          _ticket('t4', KitchenTicketStatus.cancelled),
        ];
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _SilentKitchenFeed(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(repository.viewedBatches, <List<String>>[
        <String>['t1', 't2'],
      ]);
    });

    test('stamps nothing when the board fails', () async {
      final repository = _FakeKitchenRepository()..failBoard = true;
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _SilentKitchenFeed(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(repository.viewedBatches, isEmpty);
    });

    test('an empty board sends no stamp', () async {
      final repository = _FakeKitchenRepository();
      final cubit = AdminKitchenCubit(
        repository: repository,
        realtimeFeed: _SilentKitchenFeed(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(repository.viewedBatches, isEmpty);
    });
  });
}
