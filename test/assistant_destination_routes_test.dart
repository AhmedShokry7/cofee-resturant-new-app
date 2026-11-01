import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/navigation/assistant_routes.dart';
import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';

/// The assistant used to emit raw route strings that had to be kept in sync by
/// hand with each page's `routeName`.
void main() {
  test('each destination opens the page that owns the route', () {
    expect(
      routeForAssistantDestination(AssistantDestination.coupons),
      CouponPage.routeName,
    );
    expect(
      routeForAssistantDestination(AssistantDestination.orders),
      OrdersPage.routeName,
    );
    expect(
      routeForAssistantDestination(AssistantDestination.checkout),
      CheckoutPage.routeName,
    );
  });

  test('an answer that opens no screen navigates nowhere', () {
    expect(routeForAssistantDestination(null), isNull);
  });

  test('every destination resolves to a non-empty route', () {
    for (final destination in AssistantDestination.values) {
      expect(routeForAssistantDestination(destination), isNotNull);
    }
  });
}
