import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/profile/data/model/faq_model.dart';

ProductModel _product(String id) =>
    ProductModel(id: id, name: id, price: 25, image: 'assets/images/p.png');

class _FakeCoupons implements CouponRepository {
  @override
  Future<List<CouponModel>> activeCoupons() async => const [];

  @override
  Future<ValidatedCoupon> validate({
    required String code,
    required double subtotal,
    String? branchId,
  }) =>
      throw UnimplementedError();
}

class _FakeAddresses implements AddressRepository {
  @override
  Future<List<AddressModel>> listAddresses() async => const [];

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> removeAddress(String id) async {}
}

class _FakePaymentMethods implements PaymentMethodRepository {
  @override
  Future<List<PaymentMethodModel>> activeMethods() async => const [];
}

class _FakeContent implements ContentRepository {
  @override
  Future<double> deliveryFee() async => 0;

  @override
  Future<List<FaqModel>> faqs() async => const [];

  @override
  Future<List<OnBoardingModel>> onBoardingSlides() async => const [];

  @override
  Future<LegalDocumentModel?> legalDocument(String slug) async => null;
}

class _FakeOrders implements OrdersRepository {
  _FakeOrders({this.result, this.error});

  final PlacedOrder? result;
  final Object? error;

  String? branchId;
  List<PlaceOrderLine>? lines;
  String? fulfillmentType;
  String? couponCode;

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? couponCode,
    String? note,
  }) async {
    this.branchId = branchId;
    this.lines = lines;
    this.fulfillmentType = fulfillmentType;
    this.couponCode = couponCode;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async =>
      const [];

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

PlacedOrder _placed() => PlacedOrder(
      orderId: 'oid-1',
      orderNumber: 'ORD-1',
      subtotal: 40,
      discountTotal: 0,
      deliveryFee: 0,
      taxTotal: 0,
      grandTotal: 40,
      pointsEarned: 4,
      placedAt: DateTime(2026, 1, 1),
    );

CheckoutCubit _cubit(_FakeOrders orders, {String? branchId}) => CheckoutCubit(
      coupons: _FakeCoupons(),
      addresses: _FakeAddresses(),
      paymentMethods: _FakePaymentMethods(),
      content: _FakeContent(),
      orders: orders,
      branchId: branchId,
    );

void main() {
  test('a successful placement maps every line and shows the server totals',
      () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(orders, branchId: 'branch-1');

    final placed = await cubit.placeOrder(
      items: [
        CartItem(
          product: _product('p1'),
          quantity: 2,
          note: 'Large',
          optionValueIds: const ['a'],
          bundleId: 'bundle-1',
        ),
      ],
    );

    expect(placed, isTrue);
    expect(cubit.state.isPlacingOrder, isFalse);
    expect(cubit.state.orderError, isNull);
    expect(cubit.state.lastOrder, isNotNull);
    // The receipt shows what the server persisted, not the device total.
    expect(cubit.state.lastOrder!.total, 40);
    expect(cubit.state.lastOrder!.id, 'ORD-1');

    expect(orders.branchId, 'branch-1');
    expect(orders.fulfillmentType, 'pickup');
    expect(orders.lines, hasLength(1));
    final line = orders.lines!.single;
    expect(line.productId, 'p1');
    expect(line.quantity, 2);
    expect(line.note, 'Large');
    expect(line.optionValueIds, const ['a']);
    expect(line.bundleId, 'bundle-1');

    await cubit.close();
  });

  test('a failed placement reports the error and never fabricates a receipt',
      () async {
    final orders = _FakeOrders(error: StateError('boom'));
    final cubit = _cubit(orders, branchId: 'branch-1');

    final ok = await cubit.placeOrder(
      items: [CartItem(product: _product('p1'))],
    );

    expect(ok, isFalse);
    expect(cubit.state.isPlacingOrder, isFalse);
    expect(cubit.state.lastOrder, isNull);
    expect(cubit.state.orderError, contains('boom'));

    await cubit.close();
  });

  test('a missing branch is rejected before any server call', () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(orders);

    final ok = await cubit.placeOrder(
      items: [CartItem(product: _product('p1'))],
    );

    expect(ok, isFalse);
    expect(cubit.state.orderError, isNotNull);
    expect(orders.lines, isNull);

    await cubit.close();
  });

  test('an empty cart is rejected before any server call', () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(orders, branchId: 'branch-1');

    final ok = await cubit.placeOrder(items: const []);

    expect(ok, isFalse);
    expect(cubit.state.orderError, isNotNull);
    expect(orders.lines, isNull);

    await cubit.close();
  });
}
