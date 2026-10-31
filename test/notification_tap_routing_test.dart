import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_tile.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';

/// Records where the app actually navigated, so a test asserts the destination
/// rather than only that a tap fired a callback.
class _RouteRecorder extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) pushed.add(name);
  }
}

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository(this.rows);

  List<NotificationModel> rows;

  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async =>
      rows;

  @override
  Future<int> markRead(List<String> ids) async => ids.length;
}

NotificationModel _row(
  String id, {
  String type = 'system',
  String? relatedEntityType,
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
Future<void> _pumpPage(
  WidgetTester tester,
  List<NotificationModel> rows,
  _RouteRecorder recorder,
) async {
  final cubit = NotificationsCubit(
    repository: _FakeNotificationsRepository(rows),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, _) => MaterialApp(
        navigatorObservers: [recorder],
        routes: {
          OrdersPage.routeName: (_) => const Scaffold(body: Text('orders')),
          LoyaltyPage.routeName: (_) => const Scaffold(body: Text('loyalty')),
          CouponPage.routeName: (_) => const Scaffold(body: Text('coupon')),
          NotificationsPage.routeName: (_) =>
              const Scaffold(body: Text('notifications')),
          SubscriptionDetailsPage.routeName: (_) =>
              const Scaffold(body: Text('subscription')),
        },
        home: BlocProvider.value(
          value: cubit,
          child: const NotificationsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
}
