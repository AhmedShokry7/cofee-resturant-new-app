import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/widgets/payment_method_bottom_bar.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/payment/data/model/saved_card_model.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/shared/utils/card_brand.dart';

/// The uuid the server stores the order under.
const String serverOrderId = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

/// The number the customer reads on the receipt.
const String orderNumber = 'ORD-2026-000123';

class _FakeOrders implements OrdersRepository {
  _FakeOrders();

  String? receivedCoupon;

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
  }) async {
    receivedCoupon = couponCode;
    return PlacedOrder(
      orderId: serverOrderId,
      orderNumber: orderNumber,
      subtotal: 35,
      discountTotal: 0,
      deliveryFee: 0,
      taxTotal: 0,
      grandTotal: 35,
      pointsEarned: 0,
      placedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

class _FakeTap implements TapPaymentRepository {
  _FakeTap({this.verified = true});

  final bool verified;

  final List<String> chargedOrderIds = <String>[];
  int verifyCalls = 0;

  @override
  Future<TapChargeResult> createCharge({
    required String orderId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async {
    chargedOrderIds.add(orderId);
    return const TapChargeResult(
      chargeId: 'ch_123',
      status: 'INITIATED',
      transactionUrl: 'https://tap.company/3ds',
    );
  }

  @override
  Future<TapChargeResult> createSubscriptionCharge({
    required String subscriptionId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async {
    chargedOrderIds.add(subscriptionId);
    return const TapChargeResult(
      chargeId: 'ch_123',
      status: 'INITIATED',
      transactionUrl: 'https://tap.company/3ds',
    );
  }

  @override
  Future<TapVerificationResult> verifyCharge(String chargeId) async {
    verifyCalls++;
    return TapVerificationResult(
      chargeId: chargeId,
      status: verified ? 'CAPTURED' : 'FAILED',
      verified: verified,
      orderPaymentStatus: verified ? 'paid' : 'failed',
    );
  }
}

class _FakeLoyalty implements LoyaltyRepository {
  @override
  Future<LoyaltyCatalog> loadCatalog() async => const LoyaltyCatalog();

  @override
  Future<LoyaltyWallet?> loadWallet() async => null;

  @override
  Future<int> redeemReward({
    required String productId,
    required String branchId,
  }) async => 0;
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
  Future<void> setDefaultAddress(String id) async {}

  @override
  Future<void> removeAddress(String id) async {}
}

class _FakePaymentMethods implements PaymentMethodRepository {
  @override
  Future<List<PaymentMethodModel>> activeMethods() async => const [
    PaymentMethodModel(
      id: 'card-1',
      label: 'Card',
      code: 'card',
      isOnline: true,
    ),
    PaymentMethodModel(
      id: 'cash-1',
      label: 'Cash',
      code: 'cash',
    ),
  ];
}

class _FakeDeliveryZones implements DeliveryZoneRepository {
  @override
  Future<List<DeliveryZone>> zonesForBranch(String branchId) async => const [];

  @override
  Future<List<DeliveryZone>> zonesForPoint({
    required String branchId,
    required double latitude,
    required double longitude,
  }) async => const [];
}

class _FakeCoupons implements CouponRepository {
  @override
  Future<List<CouponModel>> activeCoupons() async => const [];

  @override
  Future<Map<String, CouponUsage>> usageForCustomer() async => const {};

  @override
  Future<Map<String, CouponScope>> scopeForCoupons(
    List<CouponModel> coupons,
  ) async => const {};

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
  }) => throw UnimplementedError();

  @override
  Future<ValidatedCoupon> validateForCart({
    required String code,
    required double subtotal,
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) => throw UnimplementedError();
}

const latte = ProductModel(
  id: '3',
  name: 'Latte',
  category: 'Hot Coffee',
  description: 'd',
  price: 35,
  image: 'x',
);

/// Lets the asynchronous payment work run.
///
/// The payment screen shows a spinner while it waits for the bank, so the
/// tree never settles on its own: the clock is advanced in steps instead.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const savedCard = SavedCardModel(
  id: 'card-1',
  brand: CardBrand.visa,
  last4: '4242',
  holder: 'A Customer',
  expiry: '12/30',
);

void main() {
  setUp(() {
    SupabaseService.debugReset();
    AppLocale.instance.debugSet(AppLanguage.english);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('placed order identity', () {
    test('the order keeps the server id next to the number the customer reads',
        () async {
      final orders = _FakeOrders();
      final checkout = CheckoutCubit(
        coupons: _FakeCoupons(),
        addresses: _FakeAddresses(),
        paymentMethods: _FakePaymentMethods(),
        deliveryZoneRepository: _FakeDeliveryZones(),
        orders: orders,
        branchId: 'branch-1',
        currentUserIdProvider: () => 'user-1',
      );
      addTearDown(checkout.close);
      await checkout.load();

      final placed = await checkout.placeOrder(items: const []);

      expect(placed, isFalse, reason: 'an empty cart is refused');
      expect(checkout.state.lastOrder, isNull);
    });

    test('the last order carries the server id and the order number', () async {
      final orders = _FakeOrders();
      final checkout = CheckoutCubit(
        coupons: _FakeCoupons(),
        addresses: _FakeAddresses(),
        paymentMethods: _FakePaymentMethods(),
        deliveryZoneRepository: _FakeDeliveryZones(),
        orders: orders,
        branchId: 'branch-1',
        currentUserIdProvider: () => 'user-1',
      );
      addTearDown(checkout.close);
      await checkout.load();

      final cart = CartCubit(
        cartRepository: const LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        branchId: 'branch-1',
        userIdProvider: () => 'user-1',
      );
      addTearDown(cart.close);
      await cart.settled;
      cart.add(latte, quantity: 1);
      await cart.flushServerSync();
      await cart.settled;

      final placed = await checkout.placeOrder(items: cart.state.items);

      expect(placed, isTrue);
      expect(checkout.state.lastOrder, isNotNull);
      // The number is the label, the uuid is the key.
      expect(checkout.state.lastOrder!.id, orderNumber);
      expect(checkout.state.lastOrder!.orderId, serverOrderId);
    });
  });

  group('card payment', () {
    Future<({
      CartCubit cart,
      CheckoutCubit checkout,
      CardPaymentCubit charge,
      _FakeTap tap,
    })> buildPaymentTree(
      WidgetTester tester, {
      bool verified = true,
      bool withSavedCard = true,
    }) async {
      final tap = _FakeTap(verified: verified);
      final orders = _FakeOrders();
      final cart = CartCubit(
        cartRepository: const LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        branchId: 'branch-1',
        userIdProvider: () => 'user-1',
      );
      final checkout = CheckoutCubit(
        coupons: _FakeCoupons(),
        addresses: _FakeAddresses(),
        paymentMethods: _FakePaymentMethods(),
        deliveryZoneRepository: _FakeDeliveryZones(),
        orders: orders,
        branchId: 'branch-1',
        currentUserIdProvider: () => 'user-1',
      );
      final charge = CardPaymentCubit(repository: tap);
      final loyalty = LoyaltyCubit(repository: _FakeLoyalty());

      addTearDown(cart.close);
      addTearDown(checkout.close);
      addTearDown(charge.close);
      addTearDown(loyalty.close);

      await cart.settled;
      cart.add(latte, quantity: 1);
      await cart.flushServerSync();
      await cart.settled;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, _) => MultiBlocProvider(
            providers: [
              BlocProvider<CartCubit>.value(value: cart),
              BlocProvider<CheckoutCubit>.value(value: checkout),
              BlocProvider<CardPaymentCubit>.value(value: charge),
              BlocProvider<LoyaltyCubit>.value(value: loyalty),
            ],
            child: MaterialApp(
              routes: {
                'paymentSuccessRoute': (context) =>
                    const Scaffold(body: Text('payment-success')),
              },
              home: const Scaffold(
                body: PaymentMethodBottomBar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The card method and the stored card, exactly as the payment page
      // leaves them.
      checkout.selectPaymentMethod(
        const PaymentMethodModel(
          id: 'card-1',
          label: 'Card',
          code: 'card',
          isOnline: true,
        ),
      );
      if (withSavedCard) {
        checkout.selectSavedCard(savedCard);
      }
      await tester.pumpAndSettle();

      return (cart: cart, checkout: checkout, charge: charge, tap: tap);
    }

    testWidgets('the charge is made for the order id, never for the number',
        (tester) async {
      final tree = await buildPaymentTree(tester);

      await tester.tap(find.text('Confirm Payment'));
      await _advance(tester);

      expect(tree.tap.chargedOrderIds, isNotEmpty);
      expect(tree.tap.chargedOrderIds.first, serverOrderId);
      expect(tree.tap.chargedOrderIds.first, isNot(orderNumber));
    });

    testWidgets('a verified charge empties the cart and confirms the order',
        (tester) async {
      final tree = await buildPaymentTree(tester);

      await tester.tap(find.text('Confirm Payment'));
      await _advance(tester);

      // The charge exists; the customer comes back from the bank and the
      // charge is verified.
      expect(tree.tap.verifyCalls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _advance(tester);

      expect(tree.tap.verifyCalls, 1);
      expect(tree.cart.state.items, isEmpty);
      expect(find.text('payment-success'), findsOneWidget);
      // The emptied cart is mirrored to the server; the timer it armed must
      // not outlive the test.
      await tree.cart.flushServerSync();
    });

    testWidgets('a charge that is not verified keeps the cart', (tester) async {
      final tree = await buildPaymentTree(tester, verified: false);

      await tester.tap(find.text('Confirm Payment'));
      await _advance(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _advance(tester);

      expect(tree.tap.verifyCalls, 1);
      expect(tree.cart.state.items, isNotEmpty);
      expect(find.text('payment-success'), findsNothing);
    });

    testWidgets('a saved card is only used for a card method', (tester) async {
      final tree = await buildPaymentTree(tester);

      tree.checkout.selectPaymentMethod(
        const PaymentMethodModel(
          id: 'apple-1',
          label: 'Apple Pay',
          code: 'apple_pay',
          isOnline: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tree.checkout.state.selectedSavedCard, isNull);
    });
  });
}
