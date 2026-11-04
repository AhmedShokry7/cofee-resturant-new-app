import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';
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

/// Where one tapped notification takes the customer.
@immutable
class NotificationOpen {
  const NotificationOpen({required this.route, this.entityId});

  /// The page that owns the message.
  final String route;

  /// The record the message names, when that record has a page of its own and
  /// the row carries it. Null means the section page is as exact as the row
  /// gets, so the caller pushes the route with no argument.
  final String? entityId;
}

/// The exact destination of a notification, or null when it owns no page.
///
/// The only step beyond [routeForNotification] is the order: an order trigger
/// writes the id of the order it is about, so the customer lands on that
/// order instead of the list they have to search. A campaign carries no entity
/// at all and a subscription or a loyalty row has no screen of its own per
/// record, so those keep the section page.
///
/// Every path that opens a notification - the tile in the list, the banner of
/// a push that arrived while the app was open, and the tap on a push itself -
/// asks this function, so the three cannot lead to different places.
NotificationOpen? openForNotification({
  String? relatedEntityType,
  String? type,
  String? destination,
  String? relatedEntityId,
}) {
  final entityId = entityIdOf(relatedEntityId);
  if (destination == null && relatedEntityType == 'order' && entityId != null) {
    return NotificationOpen(
      route: OrderDetailsPage.routeName,
      entityId: entityId,
    );
  }
  final route = routeForNotification(
    relatedEntityType: relatedEntityType,
    type: type,
    destination: destination,
  );
  return route == null ? null : NotificationOpen(route: route);
}

/// A row's entity id when it really is one, otherwise null.
///
/// The id is only ever a lookup key for the customer's own records, but a
/// free-form column must not hand the navigation layer an arbitrary string.
String? entityIdOf(Object? value) => Db.uuidOrNull(value);
