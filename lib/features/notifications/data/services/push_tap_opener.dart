import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';

/// Opens the page behind the notification the customer tapped.
///
/// A tap that opens the app from a cold start arrives before there is a
/// navigator to push a route on, so the route waits in [PushService] until the
/// main page takes it. A tap while the app is already open opens the screen
/// right away.
///
/// The destination comes from [routeForNotification], the same function the
/// list uses, so a push and the matching row in the list cannot open two
/// different pages. A notification that owns no page - a system message -
/// still has to lead somewhere, so the tap opens the notifications list.
void openPushRoute(RemoteMessage message) {
  final route =
      routeForNotification(
        relatedEntityType: message.data['related_entity_type'],
        type: message.data['type'],
        destination: message.data['destination'],
      ) ??
      NotificationsPage.routeName;
  final navigator = rootNavigatorKey.currentState;
  if (navigator != null) {
    navigator.pushNamed(route);
    return;
  }
  PushService.setPendingRoute(route);
}
