import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';

/// Records where the app actually navigated, so a test asserts the destination
/// rather than only that a tap fired a callback.
class _RouteRecorder extends NavigatorObserver {
  final List<String> pushed = [];

  /// The arguments of each push, in the same order as [pushed] - a deep link is
  /// only correct if the id it names arrives with the route.
  final List<Object?> arguments = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    pushed.add(name);
    arguments.add(route.settings.arguments);
  }
}

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository(this.rows);

  List<NotificationModel> rows;
  final List<List<String>> markedIds = [];

  @override
  Future<List<NotificationModel>> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async => rows;

  @override
  Future<int> markRead(List<String> ids) async {
    markedIds.add(List<String>.of(ids));
    return ids.length;
  }

  @override
  Future<int> deleteNotifications(List<String> ids) async => 0;

  @override
  Future<int> deleteAllNotifications() async => 0;
}

NotificationModel _row(
  String id, {
  String type = 'system',
  String? relatedEntityType,
  String? relatedEntityId,
  String? destination,
  String? imageUrl,
}) => NotificationModel(
  id: id,
  titleAr: 'عنوان $id',
  titleEn: 'Title $id',
  bodyAr: 'نص',
  bodyEn: 'Body',
  type: type,
  relatedEntityType: relatedEntityType,
  relatedEntityId: relatedEntityId,
  destination: destination,
  imageUrl: imageUrl,
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  isRead: false,
);

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The real page over stub destinations, registered under the route names the
/// pages themselves declare: if a destination ever changes its route name, the
/// routing helper and this test stop agreeing and the test fails.
Future<_FakeNotificationsRepository> _pumpPage(
  WidgetTester tester,
  List<NotificationModel> rows,
  _RouteRecorder recorder,
) async {
  final repository = _FakeNotificationsRepository(rows);
  final cubit = NotificationsCubit(repository: repository);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [recorder],
      routes: {
        OrdersPage.routeName: (_) => const Scaffold(body: Text('orders')),
        LoyaltyPage.routeName: (_) => const Scaffold(body: Text('loyalty')),
        CouponPage.routeName: (_) => const Scaffold(body: Text('coupon')),
        NotificationsPage.routeName: (_) =>
            const Scaffold(body: Text('notifications')),
        SubscriptionDetailsPage.routeName: (_) =>
            const Scaffold(body: Text('subscription')),
        OrderDetailsPage.routeName: (_) =>
            const Scaffold(body: Text('order details')),
      },
      home: BlocProvider.value(value: cubit, child: const NotificationsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _tapRow(WidgetTester tester, int index) async {
  await tester.tap(find.byType(NotificationTile).at(index));
  await tester.pumpAndSettle();
}

void main() {
  group('the route of a notification', () {
    test('the entity named by the database wins', () {
      expect(
        routeForNotification(relatedEntityType: 'order', type: 'order_status'),
        OrdersPage.routeName,
      );
      expect(
        routeForNotification(relatedEntityType: 'loyalty', type: 'loyalty'),
        LoyaltyPage.routeName,
      );
      expect(
        routeForNotification(
          relatedEntityType: 'subscription',
          type: 'subscription',
        ),
        SubscriptionDetailsPage.routeName,
      );
    });

    test('a campaign without an entity routes by its type', () {
      // admin_send_notification accepts exactly these three types.
      expect(routeForNotification(type: 'promo'), CouponPage.routeName);
      expect(routeForNotification(type: 'loyalty'), LoyaltyPage.routeName);
      expect(routeForNotification(type: 'system'), isNull);
    });

    test('an order status row with no entity still reaches the orders', () {
      expect(routeForNotification(type: 'order_status'), OrdersPage.routeName);
    });

    test('an unknown entity or type opens nothing', () {
      expect(
        routeForNotification(relatedEntityType: 'branch', type: 'system'),
        isNull,
      );
      expect(routeForNotification(), isNull);
    });
  });

  group('the screen the campaign chose', () {
    test('every destination the composer offers is a registered page', () {
      expect(routeForNotification(destination: 'offers'), CouponPage.routeName);
      expect(routeForNotification(destination: 'orders'), OrdersPage.routeName);
      expect(
        routeForNotification(destination: 'loyalty'),
        LoyaltyPage.routeName,
      );
      expect(
        routeForNotification(destination: 'subscription'),
        SubscriptionDetailsPage.routeName,
      );
      expect(
        routeForNotification(destination: 'notifications'),
        NotificationsPage.routeName,
      );
    });

    test('the destination the admin picked beats the entity and the type', () {
      expect(
        routeForNotification(
          relatedEntityType: 'order',
          type: 'order_status',
          destination: 'loyalty',
        ),
        LoyaltyPage.routeName,
      );
    });

    test(
      'a destination that is not a known code falls back, never opens raw',
      () {
        // A hand-written payload could carry anything; the app still only opens
        // the page its own entity or type resolves to.
        expect(
          routeForNotification(
            relatedEntityType: 'order',
            destination: 'settings',
          ),
          OrdersPage.routeName,
        );
        expect(routeForNotification(destination: '/orders'), isNull);
        expect(routeForNotification(destination: 'orders?id=1'), isNull);
      },
    );
  });

  group('tapping a notification in the list', () {
    testWidgets('a campaign offer opens the coupons page', (tester) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      await _pumpPage(tester, [_row('promo', type: 'promo')], recorder);

      await _tapRow(tester, 0);

      expect(recorder.pushed.last, CouponPage.routeName);
    });

    testWidgets('a loyalty row opens the loyalty page', (tester) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      await _pumpPage(tester, [
        _row('points', type: 'loyalty', relatedEntityType: 'loyalty'),
      ], recorder);

      await _tapRow(tester, 0);

      expect(recorder.pushed.last, LoyaltyPage.routeName);
    });

    testWidgets('an order update opens the orders page', (tester) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      await _pumpPage(tester, [
        _row('order', type: 'order_status', relatedEntityType: 'order'),
      ], recorder);

      await _tapRow(tester, 0);

      expect(recorder.pushed.last, OrdersPage.routeName);
    });

    testWidgets('a system message stays on the list', (tester) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      await _pumpPage(tester, [_row('note', type: 'system')], recorder);
      final pushedBefore = recorder.pushed.length;

      await _tapRow(tester, 0);

      expect(recorder.pushed.length, pushedBefore);
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('an announcement aimed at the offers page opens the coupons', (
      tester,
    ) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      // A general announcement carries no entity and type `system`, so before
      // the destination existed this tap did nothing at all.
      await _pumpPage(tester, [
        _row('campaign', destination: 'offers'),
      ], recorder);

      await _tapRow(tester, 0);

      expect(recorder.pushed.last, CouponPage.routeName);
    });

    testWidgets('a destination outside the list opens nothing', (tester) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      await _pumpPage(tester, [
        _row('campaign', destination: 'settings'),
      ], recorder);
      final pushedBefore = recorder.pushed.length;

      await _tapRow(tester, 0);

      expect(recorder.pushed.length, pushedBefore);
    });
  });

  group('the order a notification names', () {
    const orderId = '4db6e1a4-2f31-4b0a-9d2b-7c1f5e6a8b90';

    test('a row that names an order opens that order', () {
      final open = openForNotification(
        relatedEntityType: 'order',
        type: 'order_status',
        relatedEntityId: orderId,
      );
      expect(open?.route, OrderDetailsPage.routeName);
      expect(open?.entityId, orderId);
    });

    test('a row that only says order still opens the list', () {
      expect(
        openForNotification(relatedEntityType: 'order')?.route,
        OrdersPage.routeName,
      );
      expect(
        openForNotification(
          relatedEntityType: 'order',
          relatedEntityId: '   ',
        )?.entityId,
        isNull,
      );
    });

    test('a value that is not a record id is never handed to navigation', () {
      // The column is free text, so anything that is not an id is dropped
      // before it can become a lookup key.
      final open = openForNotification(
        relatedEntityType: 'order',
        relatedEntityId: 'https://example.test/orders',
      );
      expect(open?.route, OrdersPage.routeName);
      expect(open?.entityId, isNull);
      expect(entityIdOf('550e8400-e29b-41d4-a716-44665544000'), isNull);
    });

    test('what the campaign chose beats the order the row names', () {
      final open = openForNotification(
        relatedEntityType: 'order',
        destination: 'loyalty',
        relatedEntityId: orderId,
      );
      expect(open?.route, LoyaltyPage.routeName);
      expect(open?.entityId, isNull);
    });

    testWidgets('the tap carries the id and marks only its own row', (
      tester,
    ) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      final repository = await _pumpPage(tester, [
        _row(
          'named',
          type: 'order_status',
          relatedEntityType: 'order',
          relatedEntityId: orderId,
        ),
        _row('other', type: 'order_status', relatedEntityType: 'order'),
      ], recorder);

      await _tapRow(tester, 0);

      expect(recorder.pushed.last, OrderDetailsPage.routeName);
      expect(recorder.arguments.last, orderId);
      expect(repository.markedIds.single, ['named']);
    });

    testWidgets('a row of another kind is pushed with no argument', (
      tester,
    ) async {
      _setSurface(tester);
      final recorder = _RouteRecorder();
      await _pumpPage(tester, [_row('points', type: 'loyalty')], recorder);

      await _tapRow(tester, 0);

      expect(recorder.pushed.last, LoyaltyPage.routeName);
      expect(recorder.arguments.last, isNull);
    });
  });
}
