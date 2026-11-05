import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_cancellation/order_cancellation_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';

/// The only write an order screen offers the customer: cancelling it.
///
/// The tracking screen used to borrow the list's [OrdersCubit] for this, which
/// was never in scope on a pushed route, so every cancel ended in a failure
/// message. These tests hold the two things that replace it: the answer reaches
/// the repository, and the route leaves with `true` so the screen above knows to
/// re-read.
class _FakeRepository implements OrdersRepository {
  _FakeRepository({this.cancelError});

  final Object? cancelError;

  String? cancelledOrderId;
  int cancelCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async {}

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    cancelCalls++;
    cancelledOrderId = orderId;
    if (gate != null) await gate!.future;
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

OrderItemModel _line({
  String id = 'line-1',
  String orderId = 'order-1',
  OrderStatus status = OrderStatus.active,
}) => OrderItemModel(
  id: id,
  product: ProductModel(
    id: 'product-1',
    nameEn: 'Latte',
    nameAr: 'لاتيه',
    price: 25,
    image: AppImages.product,
  ),
  status: status,
  quantity: 1,
  orderId: orderId,
  orderNumber: 'ORD-1',
  unitPrice: 25,
  lineTotal: 25,
  placedAt: DateTime.utc(2026, 10, 1, 10),
  databaseStatus: 'preparing',
  grandTotal: 25,
);

Future<void> _pumpApp(
  WidgetTester tester,
  OrdersRepository repository, {
  required OrderItemModel order,
}) async {
  tester.view.physicalSize = const Size(390, 1600) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepositoryProvider<OrdersRepository>.value(
      value: repository,
      child: MaterialApp(
        onGenerateRoute: AppRouteGenerator.onGenerateRoute,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(TrackOrderPage.routeName, arguments: order),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('OrderCancellationCubit', () {
    test('cancels the order it was made for', () async {
      final repository = _FakeRepository();
      final cubit = OrderCancellationCubit(
        repository: repository,
        orderId: 'order-9',
      );
      addTearDown(cubit.close);

      expect(await cubit.cancel(), isTrue);
      expect(repository.cancelledOrderId, 'order-9');
      expect(cubit.state.cancelled, isTrue);
      expect(cubit.state.error, isNull);
    });

    test('a refusal is a readable sentence, never the provider text', () async {
      final repository = _FakeRepository(
        cancelError: StateError('relation orders is not updatable'),
      );
      final cubit = OrderCancellationCubit(
        repository: repository,
        orderId: 'order-1',
      );
      addTearDown(cubit.close);

      expect(await cubit.cancel(), isFalse);
      expect(cubit.state.cancelled, isFalse);
      expect(cubit.state.errorCopy, S.couldNotCancelOrder);
    });

    test('a signed-out repository asks for the sign-in', () async {
      final repository = _FakeRepository(
        cancelError: OrderSignInRequiredException(),
      );
      final cubit = OrderCancellationCubit(
        repository: repository,
        orderId: 'order-1',
      );
      addTearDown(cubit.close);

      expect(await cubit.cancel(), isFalse);
      expect(cubit.state.errorCopy, S.signInToSeeOrders);
    });

    test(
      'a second tap while the first is on its way sends one write',
      () async {
        final repository = _FakeRepository()..gate = Completer<void>();
        final cubit = OrderCancellationCubit(
          repository: repository,
          orderId: 'order-1',
        );
        addTearDown(cubit.close);

        final first = cubit.cancel();
        final second = await cubit.cancel();

        expect(
          second,
          isFalse,
          reason: 'a queued cancel must not return success',
        );
        expect(repository.cancelCalls, 1);
        expect(cubit.state.isCancelling, isTrue);

        repository.gate!.complete();
        expect(await first, isTrue);
        expect(repository.cancelCalls, 1);
      },
    );
  });

  group('the tracking screen', () {
    testWidgets('a cancellation leaves the screen and tells the list', (
      tester,
    ) async {
      final repository = _FakeRepository();
      await _pumpApp(tester, repository, order: _line());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.cancelOrder));
      await tester.pumpAndSettle();

      expect(repository.cancelledOrderId, 'order-1');
      expect(find.byType(TrackOrderPage), findsNothing);
      expect(find.text(S.orderCancelled), findsOneWidget);
    });

    testWidgets('a failed cancellation stays open with the failure', (
      tester,
    ) async {
      final repository = _FakeRepository(cancelError: StateError('no'));
      await _pumpApp(tester, repository, order: _line());

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.cancelOrder));
      await tester.pumpAndSettle();

      expect(find.byType(TrackOrderPage), findsOneWidget);
      expect(find.text(S.couldNotCancelOrder), findsOneWidget);
    });

    testWidgets('the route pops true, so a caller can refresh', (tester) async {
      final repository = _FakeRepository();
      await _pumpApp(tester, repository, order: _line());

      Object? popped;
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator
          .pushNamed(TrackOrderPage.routeName, arguments: _line())
          .then((value) => popped = value);
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.cancelOrder).first);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
