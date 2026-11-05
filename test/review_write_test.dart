import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/review/review_cubit.dart';
import 'package:new_coffee/features/orders/presentation/views/leave_review_page.dart';
import 'package:new_coffee/features/orders/presentation/views/widgets/star_rating.dart';

/// The review the customer leaves, and the write that makes its confirmation
/// true.
///
/// The screen used to pop itself and show "review submitted" having written
/// nothing anywhere, so these tests fail if the write is removed again: one
/// rating reaches the backend, a backend that cannot take it is answered with
/// the failure, and the screen only leaves happy when the row exists.
class _FakeRepository implements OrdersRepository, ReviewRepository {
  _FakeRepository({this.submitError, this.gate});

  final Object? submitError;
  final Completer<void>? gate;

  String? productId;
  String? orderId;
  int? rating;
  String? body;
  int writeCalls = 0;

  @override
  Future<void> submitReview({
    required String productId,
    String? orderId,
    required int rating,
    String? body,
  }) async {
    writeCalls++;
    this.productId = productId;
    this.orderId = orderId;
    this.rating = rating;
    this.body = body;
    if (gate != null) await gate!.future;
    if (submitError != null) throw submitError!;
  }

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
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

/// The offline fallback's shape: orders it can read, reviews it cannot write.
class _ReadOnlyRepository implements OrdersRepository {
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
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

OrderItemModel _line({
  String productId = 'product-1',
  String orderId = 'order-1',
}) => OrderItemModel(
  id: 'line-1',
  product: ProductModel(
    id: productId,
    nameEn: 'Latte',
    nameAr: 'لاتيه',
    price: 25,
    image: AppImages.product,
  ),
  status: OrderStatus.completed,
  quantity: 1,
  orderId: orderId,
  orderNumber: 'ORD-1',
  unitPrice: 25,
  lineTotal: 25,
  placedAt: DateTime.utc(2026, 10, 1, 10),
  databaseStatus: 'completed',
  grandTotal: 25,
);

Future<void> _pumpReview(
  WidgetTester tester,
  OrdersRepository repository, {
  OrderItemModel? order,
  void Function(Object? popped)? onPop,
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
        home: Scaffold(body: const SizedBox.shrink()),
      ),
    ),
  );

  final route = tester
      .state<NavigatorState>(find.byType(Navigator))
      .pushNamed(LeaveReviewPage.routeName, arguments: order ?? _line());
  if (onPop != null) route.then(onPop);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('ReviewCubit', () {
    test('stores the rating for the product the customer bought', () async {
      final repository = _FakeRepository();
      final cubit = ReviewCubit(repository: repository);
      addTearDown(cubit.close);

      final sent = await cubit.submit(
        productId: 'product-7',
        orderId: 'order-7',
        rating: 4,
        body: 'good',
      );

      expect(sent, isTrue);
      expect(cubit.state.submitted, isTrue);
      expect(repository.productId, 'product-7');
      expect(repository.orderId, 'order-7');
      expect(repository.rating, 4);
      expect(repository.body, 'good');
    });

    test('a backend that refuses is a failure, not a silent success', () async {
      final repository = _FakeRepository(
        submitError: StateError('new row violates row-level security policy'),
      );
      final cubit = ReviewCubit(repository: repository);
      addTearDown(cubit.close);

      expect(await cubit.submit(productId: 'p', rating: 3), isFalse);
      expect(cubit.state.submitted, isFalse);
      expect(cubit.state.errorCopy, S.reviewSubmitFailed);
    });

    test('a repository with no review write cannot confirm one', () async {
      final cubit = ReviewCubit(repository: _ReadOnlyRepository());
      addTearDown(cubit.close);

      expect(await cubit.submit(productId: 'p', rating: 3), isFalse);
      expect(cubit.state.submitted, isFalse);
      expect(cubit.state.errorCopy, S.reviewSubmitFailed);
    });

    test('a signed-out customer is asked to sign in', () async {
      final repository = _FakeRepository(
        submitError: OrderSignInRequiredException(),
      );
      final cubit = ReviewCubit(repository: repository);
      addTearDown(cubit.close);

      expect(await cubit.submit(productId: 'p', rating: 3), isFalse);
      expect(cubit.state.errorCopy, S.signInToSeeOrders);
    });

    test(
      'a second tap while the first is on its way sends one write',
      () async {
        final gate = Completer<void>();
        final repository = _FakeRepository(gate: gate);
        final cubit = ReviewCubit(repository: repository);
        addTearDown(cubit.close);

        final first = cubit.submit(productId: 'p', rating: 5);
        final second = await cubit.submit(productId: 'p', rating: 1);

        expect(second, isFalse);
        expect(
          repository.rating,
          5,
          reason: 'the queued tap must not overwrite',
        );
        expect(repository.writeCalls, 1);

        gate.complete();
        expect(await first, isTrue);
        expect(repository.writeCalls, 1);
      },
    );
  });

  group('the review screen', () {
    testWidgets('sends the stars and the sentence, then leaves', (
      tester,
    ) async {
      final repository = _FakeRepository();
      Object? popped;
      await _pumpReview(tester, repository, onPop: (value) => popped = value);

      expect(find.byType(StarRating), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.starOff).at(2));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'very good');
      await tester.tap(find.text(S.submit));
      await tester.pumpAndSettle();

      expect(repository.rating, 3);
      expect(repository.body, 'very good');
      expect(repository.productId, 'product-1');
      expect(popped, isTrue, reason: 'the list needs to know the row is rated');
      expect(find.text(S.reviewSubmitted), findsOneWidget);
      expect(find.byType(LeaveReviewPage), findsNothing);
    });

    testWidgets('no stars means no write and a reason why', (tester) async {
      final repository = _FakeRepository();
      await _pumpReview(tester, repository);

      await tester.tap(find.text(S.submit));
      await tester.pumpAndSettle();

      expect(repository.writeCalls, 0);
      expect(find.byType(LeaveReviewPage), findsOneWidget);
      expect(find.text(S.selectRating), findsOneWidget);
    });

    testWidgets('a failed write keeps the screen and says so', (tester) async {
      final repository = _FakeRepository(submitError: StateError('offline'));
      await _pumpReview(tester, repository);

      await tester.tap(find.byIcon(AppIcons.starOff).at(1));
      await tester.pump();

      await tester.tap(find.text(S.submit));
      await tester.pumpAndSettle();

      expect(find.byType(LeaveReviewPage), findsOneWidget);
      expect(find.text(S.reviewSubmitFailed), findsOneWidget);
      expect(find.text(S.reviewSubmitted), findsNothing);
    });

    testWidgets('every star names itself for a screen reader', (tester) async {
      await _pumpReview(tester, _FakeRepository());

      expect(
        find.bySemanticsLabel(RegExp('^${S.rateStars(1)}\$')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^${S.rateStars(5)}\$')),
        findsOneWidget,
      );
    });
  });
}
