import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_memory_page.dart';
import 'package:new_coffee/features/checkout/presentation/views/checkout_page.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';

/// The screen the assistant asks the customer to open, or null when the answer
/// opens none.
///
/// Same shape as `routeForNotification`: the engine describes an intent and
/// this table owns the route name, so renaming a page's route cannot silently
/// break an assistant answer.
String? routeForAssistantDestination(AssistantDestination? destination) {
  return switch (destination) {
    null => null,
    AssistantDestination.coupons => CouponPage.routeName,
    AssistantDestination.orders => OrdersPage.routeName,
    AssistantDestination.checkout => CheckoutPage.routeName,
    AssistantDestination.memory => AssistantMemoryPage.routeName,
  };
}
