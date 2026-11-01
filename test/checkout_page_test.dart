import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/checkout/data/repositories/payment_method_repository.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'support/mock_product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

class _FakeAddresses implements AddressRepository {
  @override
  Future<List<AddressModel>> listAddresses() async => const [];
  @override
  Future<AddressModel> addAddress({required String label, required String details, double? latitude, double? longitude, bool isDefault = false}) => throw UnimplementedError();
  @override
  Future<AddressModel> updateAddress({required String id, required String label, required String details, double? latitude, double? longitude}) => throw UnimplementedError();
  @override
  Future<void> setDefaultAddress(String id) async {}
  @override
  Future<void> removeAddress(String id) async {}
}

class _FakePaymentMethods implements PaymentMethodRepository {
  @override
  Future<List<PaymentMethodModel>> activeMethods() async => const [];
}

class _FakeDeliveryZones implements DeliveryZoneRepository {
  @override
  Future<List<DeliveryZone>> zonesForBranch(String branchId) async => const [];
  @override
  Future<List<DeliveryZone>> zonesForPoint({required String branchId, required double latitude, required double longitude}) async => const [];
}

class _FakeCoupons implements CouponRepository {
  @override
  Future<List<CouponModel>> activeCoupons() async => const [];
  @override
  Future<Map<String, CouponUsage>> usageForCustomer() async => const {};
  @override
  Future<Map<String, CouponScope>> scopeForCoupons(List<CouponModel> coupons) async => const {};
  @override
  Future<List<CouponLineDiscount>> lineBreakdown({required String code, required String branchId, required double subtotal, required List<PlaceOrderLine> lines}) async => const [];
  @override
  Future<ValidatedCoupon> validate({required String code, required double subtotal, String? branchId}) => throw UnimplementedError();
  @override
  Future<ValidatedCoupon> validateForCart({required String code, required double subtotal, required String branchId, required List<PlaceOrderLine> lines}) => throw UnimplementedError();
}

class _FakeOrders implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({OrderStatus? status, int limit = 100}) async => const [];
  @override
  Future<void> syncCart({required String branchId, required List<PlaceOrderLine> lines}) async {}
  @override
  Future<PlacedOrder> placeOrder({required String branchId, required List<PlaceOrderLine> lines, required String idempotencyKey, String fulfillmentType = 'pickup', String? deliveryZoneId, String? addressId, String? couponCode, String? note}) => throw UnimplementedError();
  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

void main() {
  setUp(() {
    SupabaseService.debugReset();
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('guests can review checkout and are asked to sign in before payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (context, _) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => CartCubit(
                cartRepository: LocalCartRepository(),
                catalogRepository: MockProductRepository(),
              ),
            ),
            BlocProvider(
              create: (_) => CheckoutCubit(
                coupons: _FakeCoupons(),
                addresses: _FakeAddresses(),
                paymentMethods: _FakePaymentMethods(),
                deliveryZoneRepository: _FakeDeliveryZones(),
                orders: _FakeOrders(),
                branchId: 'branch-1',
              ),
            ),
          ],
          child: const MaterialApp(home: CheckoutPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(S.checkout), findsOneWidget);
    expect(find.text(S.signIn), findsOneWidget);
    expect(find.text(S.proceedToCheckout), findsNothing);
  });
}