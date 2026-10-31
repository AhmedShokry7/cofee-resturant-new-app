import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';

/// The screen a notification opens, or null when it owns no page.
///
/// Three sources, in this order:
///
///   * `destination` — the screen the admin chose while composing the
///     campaign. It is a code from a fixed list, never a path, so a campaign
///     cannot ask the app to navigate somewhere it does not know;
///   * the entity behind the row, because the database names it precisely:
///     order triggers write `order`, loyalty ledger triggers write `loyalty`
///     and subscription triggers write `subscription`;
///   * the type, for a campaign that carries no entity at all, since
///     `admin_send_notification` accepts only `promo`, `loyalty` and `system`.
///
/// Both the tile in the notifications list and the tap on a push ask this
/// function, so the two paths cannot drift apart. The callers choose their own
/// fallback: the list stays where it is when this returns null, while a push
/// tap opens the notifications page rather than appearing to do nothing.
String? routeForNotification({
  String? relatedEntityType,
  String? type,
  String? destination,
}) {
  return switch (destination) {
    'offers' => CouponPage.routeName,
    'orders' => OrdersPage.routeName,
    'loyalty' => LoyaltyPage.routeName,
    'subscription' => SubscriptionDetailsPage.routeName,
    'notifications' => NotificationsPage.routeName,
    _ => switch (relatedEntityType) {
      'order' => OrdersPage.routeName,
      'loyalty' => LoyaltyPage.routeName,
      'subscription' => SubscriptionDetailsPage.routeName,
      _ => switch (type) {
        'order_status' => OrdersPage.routeName,
        'loyalty' => LoyaltyPage.routeName,
        'promo' => CouponPage.routeName,
        'subscription' => SubscriptionDetailsPage.routeName,
        _ => null,
      },
    },
  };
}
