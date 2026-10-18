import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/shipping_addresses_page_body.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

ProductModel _product(String id) =>
    ProductModel(id: id, name: id, price: 25, image: 'assets/images/p.png');

class _FakeCoupons implements CouponRepository {
  _FakeCoupons({this.result, this.error, this.syncError, this.breakdown = const []});

  final ValidatedCoupon Function(String code, double subtotal)? result;

  /// Per-line attribution the fake server hands back on apply.
  List<CouponLineDiscount> breakdown;
  Object? error;
  Object? syncError;
  int calls = 0;
  int cartValidationCalls = 0;
  List<PlaceOrderLine>? validatedCartLines;

  @override
  Future<List<CouponModel>> activeCoupons() async => const [];
  @override
  Future<Map<String, CouponUsage>> usageForCustomer() async => const {};
  @override
  Future<Map<String, CouponScope>> scopeForCoupons(List<CouponModel> coupons) async => const {};
  @override
  Future<List<CouponLineDiscount>> lineBreakdown({
    required String code,
    required String branchId,
    required double subtotal,
    required List<PlaceOrderLine> lines,
  }) async => breakdown;

  @override
  Future<ValidatedCoupon> validate({
    required String code,
    required double subtotal,
    String? branchId,
  }) async {
    calls++;
    if (error != null) throw error!;
    final build = result;
    if (build == null) throw UnimplementedError();
    return build(code, subtotal);
  }

  @override
  Future<ValidatedCoupon> validateForCart({
    required String code,
    required double subtotal,
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) {
    cartValidationCalls++;
    validatedCartLines = lines;
    if (syncError != null) throw syncError!;
    return validate(code: code, subtotal: subtotal, branchId: branchId);
  }
}

/// Answers coupon validations only when the test completes them, so a test can
/// control the order two in-flight validations finish in.
class _DeferredCoupons implements CouponRepository {
  final List<Completer<ValidatedCoupon>> pending = [];

  @override
  Future<List<CouponModel>> activeCoupons() async => const [];
  @override
  Future<Map<String, CouponUsage>> usageForCustomer() async => const {};
  @override
  Future<Map<String, CouponScope>> scopeForCoupons(List<CouponModel> coupons) async => const {};
  @override
  Future<List<CouponLineDiscount>> lineBreakdown({
    required String code,
    required String branchId,
    required double subtotal,
    required List<PlaceOrderLine> lines,
  }) async => const [];

  @override
  Future<ValidatedCoupon> validate({
    required String code,
    required double subtotal,
    String? branchId,
  }) {
    final completer = Completer<ValidatedCoupon>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<ValidatedCoupon> validateForCart({
    required String code,
    required double subtotal,
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) => validate(code: code, subtotal: subtotal, branchId: branchId);
}

class _FakeAddresses implements AddressRepository {
  _FakeAddresses([this.addresses = const []]);

  final List<AddressModel> addresses;

  /// When non-null, `setDefaultAddress` throws this error. Defaults to null,
  /// i.e. success, so existing tests keep passing.
  Object? setDefaultError;

  int setDefaultCalls = 0;

  @override
  Future<List<AddressModel>> listAddresses() async => addresses;

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) => throw UnimplementedError();

  @override
  Future<AddressModel> updateAddress({
    required String id,
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  }) => throw UnimplementedError();

  @override
  Future<void> setDefaultAddress(String id) async {
    setDefaultCalls++;
    final error = setDefaultError;
    if (error != null) throw error;
  }

  @override
  Future<void> removeAddress(String id) async {}
}

class _FakePaymentMethods implements PaymentMethodRepository {
  @override
  Future<List<PaymentMethodModel>> activeMethods() async => const [];
}

class _FakeDeliveryZones implements DeliveryZoneRepository {
  _FakeDeliveryZones([this.zones = const []]);

  final List<DeliveryZone> zones;

  @override
  Future<List<DeliveryZone>> zonesForBranch(String branchId) async => zones;
  @override
  Future<List<DeliveryZone>> zonesForPoint({
    required String branchId,
    required double latitude,
    required double longitude,
  }) async => zones;
}

class _ThrowingDeliveryZones implements DeliveryZoneRepository {
  _ThrowingDeliveryZones(this.failure);

  final DeliveryZonesFailure failure;

  @override
  Future<List<DeliveryZone>> zonesForBranch(String branchId) async =>
      throw DeliveryZonesException(failure);

  @override
  Future<List<DeliveryZone>> zonesForPoint({
    required String branchId,
    required double latitude,
    required double longitude,
  }) async => throw DeliveryZonesException(failure);
}

class _FakeOrders implements OrdersRepository {
  _FakeOrders({
    this.result,
    this.error,
    this.syncError,
    this.failFirstAfterCommit = false,
  });

  final PlacedOrder? result;
  Object? error;
  final Object? syncError;
  final bool failFirstAfterCommit;

  String? branchId;
  List<PlaceOrderLine>? lines;
  String? fulfillmentType;
  String? deliveryZoneId;
  String? addressId;
  String? couponCode;

  int syncCount = 0;
  List<PlaceOrderLine>? syncedLines;
  final List<String> idempotencyKeys = [];
  final Map<String, PlacedOrder> committedByKey = {};
  int placeCalls = 0;
  Completer<PlacedOrder>? pendingPlace;

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async {
    syncCount++;
    syncedLines = lines;
    if (syncError != null) throw syncError!;
  }

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
  }) async {
    placeCalls++;
    idempotencyKeys.add(idempotencyKey);
    this.branchId = branchId;
    this.lines = lines;
    this.fulfillmentType = fulfillmentType;
    this.deliveryZoneId = deliveryZoneId;
    this.addressId = addressId;
    this.couponCode = couponCode;
    final committed = committedByKey[idempotencyKey];
    if (committed != null) return committed;
    if (pendingPlace != null) return pendingPlace!.future;
    if (error != null) throw error!;
    if (failFirstAfterCommit && placeCalls == 1) {
      // The fake records the committed result, then simulates losing its reply.
      committedByKey[idempotencyKey] = result!;
      throw StateError('response lost after server commit');
    }
    return committedByKey[idempotencyKey] = result!;
  }

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

PlacedOrder _placed({double deliveryFee = 0}) => PlacedOrder(
  orderId: 'oid-1',
  orderNumber: 'ORD-1',
  subtotal: 40,
  discountTotal: 0,
  deliveryFee: deliveryFee,
  taxTotal: 0,
  grandTotal: 40 + deliveryFee,
  pointsEarned: 4,
  placedAt: DateTime(2026, 1, 1),
);

const _zone = DeliveryZone(
  id: 'zone-1',
  nameAr: 'منطقة',
  nameEn: 'Zone',
  deliveryFee: 25,
  minOrderAmount: 0,
);

const _address = AddressModel(
  id: 'addr-1',
  label: 'Home',
  details: '1 Test Street',
);

CheckoutCubit _cubit(
  _FakeOrders orders, {
  String? branchId,
  String? Function()? currentUserIdProvider,
  List<DeliveryZone> zones = const [],
  List<AddressModel> addresses = const [],
  DeliveryZoneRepository? deliveryZones,
  CouponRepository? coupons,
  _FakeAddresses? addressesRepository,
}) => CheckoutCubit(
  coupons: coupons ?? _FakeCoupons(),
  addresses: addressesRepository ?? _FakeAddresses(addresses),
  paymentMethods: _FakePaymentMethods(),
  deliveryZoneRepository: deliveryZones ?? _FakeDeliveryZones(zones),
  orders: orders,
  currentUserIdProvider: currentUserIdProvider,
  branchId: branchId,
);

CartItem _line(
  String id, {
  int quantity = 1,
  String note = '',
  List<String> options = const [],
}) => CartItem(
  product: _product(id),
  quantity: quantity,
  note: note,
  optionValueIds: options,
);

ValidatedCoupon _validated(
  String code, {
  required double discount,
  required double subtotal,
}) => ValidatedCoupon(
  coupon: CouponModel(id: 'coupon-$code', code: code),
  discount: discount,
  subtotal: subtotal,
);

void main() {
  // ---------- Per-line discount breakdown ----------

  test('applying a coupon fetches the per-line breakdown', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 6, subtotal: subtotal),
      // _line builds a 25.00 line; quantity 2 is the eligible one.
      breakdown: const [
        CouponLineDiscount(
          productId: 'p1',
          nameEn: 'Latte',
          lineTotal: 50,
          discount: 6,
        ),
        CouponLineDiscount(
          productId: 'p2',
          nameEn: 'Cookie',
          lineTotal: 25,
          discount: 0,
          isEligible: false,
        ),
      ],
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    final applied = await cubit.applyCoupon(
      'COLD',
      items: [_line('p1', quantity: 2), _line('p2')],
    );

    expect(applied, isTrue);
    final state = cubit.state.appliedCoupon!;
    expect(state.lines, hasLength(2));
    // The explanation never changes the money.
    expect(state.discount, 6);
    expect(cubit.summary(75).discount, 6);
    expect(cubit.summary(75).total, 69);
    expect(state.discountedLines.single.productId, 'p1');
    expect(state.isPartial, isTrue);
    await cubit.close();
  });

  test('a missing breakdown still applies the discount', () async {
    // An older deployment has no breakdown RPC. The total is already approved
    // and correct, so losing the explanation must not lose the discount.
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 6.25, subtotal: subtotal),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    final applied = await cubit.applyCoupon('SAVE25', items: [_line('p1')]);

    expect(applied, isTrue);
    expect(cubit.state.appliedCoupon!.discount, 6.25);
    expect(cubit.state.appliedCoupon!.lines, isEmpty);
    // _line is a 25.00 line, and the approval is priced for exactly that cart.
    expect(cubit.summary(25).discount, 6.25);
    await cubit.close();
  });

  test('removing the coupon drops the breakdown with it', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 2.4, subtotal: subtotal),
      breakdown: const [
        CouponLineDiscount(
          productId: 'p1',
          lineTotal: 12,
          discount: 2.4,
        ),
      ],
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();
    await cubit.applyCoupon('COLD', items: [_line('p1')]);
    expect(cubit.state.appliedCoupon!.lines, isNotEmpty);

    cubit.removeCoupon();

    expect(cubit.state.appliedCoupon, isNull);
    // The approval only ever applied to the cart it was priced for.
    expect(cubit.summary(25).discount, 0);
    await cubit.close();
  });

  test(
    'a successful setDefault updates the default flag without changing the list',
    () async {
      final addresses = [
        AddressModel(id: 'a1', label: 'Home', details: 'Street 1'),
        AddressModel(id: 'a2', label: 'Work', details: 'Street 2'),
      ];
      final repository = _FakeAddresses(addresses);
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(orders, addressesRepository: repository);
      await cubit.load();

      await cubit.setDefaultAddress('a2');

      expect(repository.setDefaultCalls, 1);
      expect(cubit.state.addresses, hasLength(2));
      expect(
        cubit.state.addresses.firstWhere((a) => a.id == 'a2').isDefault,
        isTrue,
      );
      expect(
        cubit.state.addresses.firstWhere((a) => a.id == 'a1').isDefault,
        isFalse,
      );
      expect(cubit.state.error, isNull);
    },
  );

  test(
    'a failed setDefault reports the error and keeps the previous default',
    () async {
      final addresses = [
        AddressModel(
          id: 'a1',
          label: 'Home',
          details: 'Street 1',
          isDefault: true,
        ),
        AddressModel(id: 'a2', label: 'Work', details: 'Street 2'),
      ];
      final repository = _FakeAddresses(addresses)
        ..setDefaultError = StateError('boom');
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(orders, addressesRepository: repository);
      await cubit.load();

      await cubit.setDefaultAddress('a2');

      expect(repository.setDefaultCalls, 1);
      // The repository failure must not be swallowed.
      expect(cubit.state.error, isNotNull);
      // The address list is preserved unchanged.
      expect(cubit.state.addresses, hasLength(2));
      expect(
        cubit.state.addresses.firstWhere((a) => a.id == 'a1').isDefault,
        isTrue,
        reason: 'a failed default change must not flip the local flag',
      );
      expect(
        cubit.state.addresses.firstWhere((a) => a.id == 'a2').isDefault,
        isFalse,
      );
    },
  );

  test(
    'a successful placement maps every line and shows the server totals',
    () async {
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(orders, branchId: 'branch-1');
      await cubit.load();

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
      expect(orders.deliveryZoneId, isNull);
      expect(orders.addressId, isNull);
      expect(orders.lines, hasLength(1));
      final line = orders.lines!.single;
      expect(line.productId, 'p1');
      expect(line.quantity, 2);
      expect(line.note, 'Large');
      expect(line.optionValueIds, const ['a']);
      expect(line.bundleId, 'bundle-1');

      await cubit.close();
    },
  );

  test(
    'a failed placement reports the error and never fabricates a receipt',
    () async {
      final orders = _FakeOrders(error: StateError('boom'));
      final cubit = _cubit(orders, branchId: 'branch-1');
      await cubit.load();

      final ok = await cubit.placeOrder(
        items: [CartItem(product: _product('p1'))],
      );

      expect(ok, isFalse);
      expect(cubit.state.isPlacingOrder, isFalse);
      expect(cubit.state.lastOrder, isNull);
      expect(cubit.state.orderError, contains('boom'));

      await cubit.close();
    },
  );

  test('a missing branch is rejected before any server call', () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(orders);
    await cubit.load();

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
    await cubit.load();

    final ok = await cubit.placeOrder(items: const []);

    expect(ok, isFalse);
    expect(cubit.state.orderError, isNotNull);
    expect(orders.lines, isNull);

    await cubit.close();
  });

  test(
    'delivery passes the selected zone and address and prices the zone fee',
    () async {
      final orders = _FakeOrders(result: _placed(deliveryFee: 25));
      final cubit = _cubit(
        orders,
        branchId: 'branch-1',
        zones: const [_zone],
        addresses: const [_address],
      );
      await cubit.load();

      expect(cubit.state.deliveryZones, hasLength(1));
      expect(cubit.state.fulfillment, FulfillmentType.pickup);
      expect(cubit.summary(40).deliveryFee, 0);

      cubit.setFulfillment(FulfillmentType.delivery);
      expect(cubit.state.fulfillment, FulfillmentType.delivery);
      expect(cubit.state.selectedDeliveryZone?.id, 'zone-1');
      // Delivery fee is the zone's own fee, never the pickup default.
      expect(cubit.summary(40).deliveryFee, 25);

      final placed = await cubit.placeOrder(
        items: [CartItem(product: _product('p1'))],
      );

      expect(placed, isTrue);
      expect(orders.fulfillmentType, 'delivery');
      expect(orders.deliveryZoneId, 'zone-1');
      expect(orders.addressId, 'addr-1');

      await cubit.close();
    },
  );

  test('delivery is refused when the branch serves no zones', () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(orders, branchId: 'branch-1');
    await cubit.load();

    final applied = cubit.setFulfillment(FulfillmentType.delivery);

    expect(applied, isFalse);
    expect(cubit.state.fulfillment, FulfillmentType.pickup);
    expect(cubit.state.orderError, S.deliveryUnavailable);
    expect(cubit.state.deliveryBlocked, isTrue);

    await cubit.close();
  });

  test(
    'a missing delivery-zones bridge is a load failure, not "no zones"',
    () async {
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(
        orders,
        branchId: 'branch-1',
        deliveryZones: _ThrowingDeliveryZones(
          DeliveryZonesFailure.bridgeMissing,
        ),
      );
      await cubit.load();

      expect(cubit.state.deliveryZones, isEmpty);
      expect(cubit.state.deliveryZonesLoadFailed, isTrue);
      expect(cubit.state.fulfillment, FulfillmentType.pickup);

      await cubit.close();
    },
  );

  test('a network or permission error is reported as a load failure', () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(
      orders,
      branchId: 'branch-1',
      deliveryZones: _ThrowingDeliveryZones(DeliveryZonesFailure.backendError),
    );
    await cubit.load();

    expect(cubit.state.deliveryZonesLoadFailed, isTrue);
    expect(cubit.state.fulfillment, FulfillmentType.pickup);

    await cubit.close();
  });

  test(
    'a failed zone load refuses delivery with the load-failure message',
    () async {
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(
        orders,
        branchId: 'branch-1',
        deliveryZones: _ThrowingDeliveryZones(
          DeliveryZonesFailure.bridgeMissing,
        ),
      );
      await cubit.load();

      final applied = cubit.setFulfillment(FulfillmentType.delivery);

      expect(applied, isFalse);
      expect(cubit.state.fulfillment, FulfillmentType.pickup);
      expect(cubit.state.orderError, S.deliveryUnavailableError);
      expect(cubit.state.deliveryBlocked, isTrue);

      await cubit.close();
    },
  );

  test(
    'a blocked delivery request cannot be silently placed as pickup',
    () async {
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(orders, branchId: 'branch-1');
      await cubit.load();

      cubit.setFulfillment(FulfillmentType.delivery);
      final ok = await cubit.placeOrder(
        items: [CartItem(product: _product('p1'))],
      );

      expect(ok, isFalse);
      expect(cubit.state.orderError, S.deliveryChoosePickup);
      expect(orders.lines, isNull); // the server is never called

      await cubit.close();
    },
  );

  test(
    'checkout proceeds after the shopper explicitly chooses pickup',
    () async {
      final orders = _FakeOrders(result: _placed());
      final cubit = _cubit(orders, branchId: 'branch-1');
      await cubit.load();

      cubit.setFulfillment(FulfillmentType.delivery);
      expect(cubit.state.deliveryBlocked, isTrue);

      cubit.setFulfillment(FulfillmentType.pickup);
      expect(cubit.state.deliveryBlocked, isFalse);
      expect(cubit.state.orderError, isNull);

      final ok = await cubit.placeOrder(
        items: [CartItem(product: _product('p1'))],
      );

      expect(ok, isTrue);
      expect(orders.fulfillmentType, 'pickup');

      await cubit.close();
    },
  );

  test(
    'delivery without a saved address is rejected before any server call',
    () async {
      final orders = _FakeOrders(result: _placed(deliveryFee: 25));
      final cubit = _cubit(orders, branchId: 'branch-1', zones: const [_zone]);
      await cubit.load();

      cubit.setFulfillment(FulfillmentType.delivery);
      final ok = await cubit.placeOrder(
        items: [CartItem(product: _product('p1'))],
      );

      expect(ok, isFalse);
      expect(cubit.state.orderError, isNotNull);
      expect(orders.lines, isNull);

      await cubit.close();
    },
  );

  // ---------- F3: server-approved coupon, tied to one cart ----------

  test(
    'a product-scoped coupon shows the server discount, not a recompute',
    () async {
      final orders = _FakeOrders(result: _placed());
      final coupons = _FakeCoupons(
        result: (code, subtotal) =>
            _validated(code, discount: 6.25, subtotal: subtotal),
      );
      final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
      await cubit.load();

      // p1 eligible, p2 ineligible; 25% of the whole 50 would be 12.5.
      final items = [_line('p1'), _line('p2')];
      final applied = await cubit.applyCoupon('SAVE25', items: items);

      expect(applied, isTrue);
      expect(cubit.state.appliedCoupon!.discount, 6.25);
      expect(cubit.summary(50).discount, 6.25);
      expect(cubit.summary(50).total, 43.75);
      expect(cubit.summary(50).discount, isNot(12.5));
      // Cart replacement and scoped validation now share one server RPC.
      expect(coupons.cartValidationCalls, 1);
      expect(coupons.validatedCartLines, hasLength(2));
      expect(orders.syncCount, 0);

      await cubit.close();
    },
  );

  test('a coupon is dropped when the eligible line is removed', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 6.25, subtotal: subtotal),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    await cubit.applyCoupon('SAVE25', items: [_line('p1'), _line('p2')]);
    expect(cubit.state.appliedCoupon, isNotNull);

    cubit.onCartChanged([_line('p2')]);

    expect(cubit.state.appliedCoupon, isNull);
    expect(cubit.summary(25).discount, 0);

    await cubit.close();
  });

  test(
    'a coupon is dropped when a quantity changes after validation',
    () async {
      final orders = _FakeOrders(result: _placed());
      final coupons = _FakeCoupons(
        result: (code, subtotal) =>
            _validated(code, discount: 5, subtotal: subtotal),
      );
      final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
      await cubit.load();

      await cubit.applyCoupon('SAVE', items: [_line('p1')]);
      expect(cubit.state.appliedCoupon, isNotNull);

      cubit.onCartChanged([_line('p1', quantity: 2)]);

      expect(cubit.state.appliedCoupon, isNull);

      await cubit.close();
    },
  );

  test('a coupon is dropped when an ineligible line is added', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 5, subtotal: subtotal),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    await cubit.applyCoupon('SAVE', items: [_line('p1')]);
    expect(cubit.state.appliedCoupon, isNotNull);

    cubit.onCartChanged([_line('p1'), _line('p3')]);

    expect(cubit.state.appliedCoupon, isNull);

    await cubit.close();
  });

  test('a coupon is dropped when a line options change', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 5, subtotal: subtotal),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    await cubit.applyCoupon('SAVE', items: [_line('p1')]);
    expect(cubit.state.appliedCoupon, isNotNull);

    cubit.onCartChanged([
      _line('p1', options: const ['opt-large']),
    ]);

    expect(cubit.state.appliedCoupon, isNull);

    await cubit.close();
  });

  test('a coupon is dropped on a branch change', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 5, subtotal: subtotal),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    await cubit.applyCoupon('SAVE', items: [_line('p1')]);
    expect(cubit.state.appliedCoupon, isNotNull);

    cubit.setBranch('branch-2');

    expect(cubit.state.appliedCoupon, isNull);

    await cubit.close();
  });

  test(
    'a slower earlier validation never overwrites the newer answer',
    () async {
      final orders = _FakeOrders(result: _placed());
      final coupons = _DeferredCoupons();
      final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
      await cubit.load();

      final items = [_line('p1')];
      final first = cubit.applyCoupon('FIRST', items: items);
      await Future<void>.delayed(Duration.zero);
      expect(coupons.pending, hasLength(1));

      // A second request starts while the first is still waiting on the server.
      final second = cubit.applyCoupon('SECOND', items: items);
      await Future<void>.delayed(Duration.zero);
      expect(coupons.pending, hasLength(2));

      // The newer request answers first; the older one lands late.
      coupons.pending[1].complete(
        _validated('SECOND', discount: 5, subtotal: 25),
      );
      await second;
      coupons.pending[0].complete(
        _validated('FIRST', discount: 9, subtotal: 25),
      );
      await first;

      expect(cubit.state.appliedCoupon!.coupon.code, 'SECOND');
      expect(cubit.summary(25).discount, 5);

      await cubit.close();
    },
  );

  test('a failed cart sync leaves no coupon applied', () async {
    final orders = _FakeOrders(result: _placed(), syncError: StateError('offline'));
    final coupons = _FakeCoupons(
      result: (code, subtotal) =>
          _validated(code, discount: 5, subtotal: subtotal),
      syncError: StateError('offline'),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    final applied = await cubit.applyCoupon('SAVE', items: [_line('p1')]);

    expect(applied, isFalse);
    expect(cubit.state.appliedCoupon, isNull);
    expect(cubit.state.couponError, S.couponCheckFailed);
    expect(cubit.summary(25).discount, 0);

    await cubit.close();
  });

  test('a rejected validation leaves no coupon applied', () async {
    final orders = _FakeOrders(result: _placed());
    final coupons = _FakeCoupons(
      error: const CouponRejectedException('code does not apply to your items'),
    );
    final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
    await cubit.load();

    final applied = await cubit.applyCoupon('NOPE', items: [_line('p1')]);

    expect(applied, isFalse);
    expect(cubit.state.appliedCoupon, isNull);
    expect(cubit.state.couponError, 'code does not apply to your items');

    await cubit.close();
  });

  test(
    'the server re-validates the coupon at placement and prices the order',
    () async {
      final orders = _FakeOrders(result: _placed());
      final coupons = _FakeCoupons(
        result: (code, subtotal) =>
            _validated(code, discount: 5, subtotal: subtotal),
      );
      final cubit = _cubit(orders, branchId: 'branch-1', coupons: coupons);
      await cubit.load();

      await cubit.applyCoupon('SAVE', items: [_line('p1')]);
      final ok = await cubit.placeOrder(items: [_line('p1')]);

      expect(ok, isTrue);
      expect(coupons.cartValidationCalls, 1);
      expect(coupons.validatedCartLines, hasLength(1));
      expect(orders.syncCount, 0);
      // The code travels; the server re-prices it and the receipt is its total.
      expect(orders.couponCode, 'SAVE');
      expect(cubit.state.lastOrder!.total, 40);

      await cubit.close();
    },
  );

  test(
    'a retry after an ambiguous response reuses its idempotency key',
    () async {
      final orders = _FakeOrders(result: _placed(), failFirstAfterCommit: true);
      final cubit = _cubit(orders, branchId: 'branch-1');
      await cubit.load();

      expect(await cubit.placeOrder(items: [_line('p1')]), isFalse);
      final firstKey = orders.idempotencyKeys.single;
      expect(await cubit.placeOrder(items: [_line('p1')]), isTrue);

      expect(orders.idempotencyKeys, [firstKey, firstKey]);
      await cubit.close();
    },
  );

  test(
    'an ambiguous order retry after checkout recreation reuses its key',
    () async {
      SharedPreferences.setMockInitialValues({});
      const userId = 'user-persisted';
      final firstOrders = _FakeOrders(
        result: _placed(),
        failFirstAfterCommit: true,
      );
      final firstCubit = _cubit(
        firstOrders,
        branchId: 'branch-1',
        currentUserIdProvider: () => userId,
      );
      await firstCubit.load();
      expect(await firstCubit.placeOrder(items: [_line('p1')]), isFalse);
      final firstKey = firstOrders.idempotencyKeys.single;
      await firstCubit.close();

      final retryOrders = _FakeOrders(result: _placed());
      final retryCubit = _cubit(
        retryOrders,
        branchId: 'branch-1',
        currentUserIdProvider: () => userId,
      );
      await retryCubit.load();
      expect(await retryCubit.placeOrder(items: [_line('p1')]), isTrue);

      expect(retryOrders.idempotencyKeys.single, firstKey);
      await retryCubit.close();
    },
  );

  test('a successful new purchase gets a different key', () async {
    final orders = _FakeOrders(result: _placed());
    final cubit = _cubit(orders, branchId: 'branch-1');
    await cubit.load();

    expect(await cubit.placeOrder(items: [_line('p1')]), isTrue);
    final firstKey = orders.idempotencyKeys.single;
    expect(await cubit.placeOrder(items: [_line('p1')]), isTrue);

    expect(orders.idempotencyKeys, hasLength(2));
    expect(orders.idempotencyKeys[1], isNot(firstKey));
    await cubit.close();
  });

  test('a changed order after a failed attempt gets a new key', () async {
    final orders = _FakeOrders(
      result: _placed(),
      error: StateError('network error'),
    );
    final cubit = _cubit(orders, branchId: 'branch-1');
    await cubit.load();

    expect(await cubit.placeOrder(items: [_line('p1')]), isFalse);
    final firstKey = orders.idempotencyKeys.single;
    orders.error = null;
    // A different line is a distinct logical purchase even while the former
    // request remains uncertain.
    expect(await cubit.placeOrder(items: [_line('p2')]), isTrue);
    expect(orders.idempotencyKeys[1], isNot(firstKey));
    await cubit.close();
  });

  test(
    'a concurrent confirmation is ignored while the first is pending',
    () async {
      final orders = _FakeOrders(result: _placed())
        ..pendingPlace = Completer<PlacedOrder>();
      final cubit = _cubit(orders, branchId: 'branch-1');
      await cubit.load();

      final first = cubit.placeOrder(items: [_line('p1')]);
      await Future<void>.delayed(Duration.zero);
      expect(await cubit.placeOrder(items: [_line('p1')]), isFalse);
      orders.pendingPlace!.complete(_placed());
      expect(await first, isTrue);

      expect(orders.idempotencyKeys, hasLength(1));
      await cubit.close();
    },
  );

  testWidgets(
    'a failed set-default shows a snackbar on the shipping addresses screen',
    (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MaterialApp(
            home: BlocProvider<CheckoutCubit>(
              create: (_) => _cubit(
                _FakeOrders(result: _placed()),
                addressesRepository: _FakeAddresses([
                  const AddressModel(
                    id: 'a1',
                    label: 'Home',
                    details: 'Street 1',
                    isDefault: true,
                  ),
                  const AddressModel(id: 'a2', label: 'Work', details: 'Street 2'),
                ])..setDefaultError = StateError('rpc failed'),
              ),
              child: const Scaffold(body: ShippingAddressesPageBody()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(S.setDefaultAddress));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(S.addressSaveFailed), findsOneWidget);
    },
  );
}
