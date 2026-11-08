import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';

/// The banners shown for a push that arrives while the app is open.
///
/// The system drawer is silent in that case, so the message is read from the
/// data of the push in the language the customer uses, and it can be opened
/// from the banner the same way a banner of a closed app is.
///
/// The banner lives on the messenger of the root navigator: a push can arrive
/// on any screen, and the customer must be able to read it without whatever
/// screen they are on being replaced.
class ForegroundPushBanners {
  StreamSubscription<RemoteMessage>? _subscription;

  /// Starts showing the banners. Safe to call once, from the app root.
  void start() {
    _subscription ??= PushService.onForegroundMessage.listen(_show);
  }

  /// Stops the banners, so a message cannot reach a messenger that is gone.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _show(RemoteMessage message) {
    final arabic = AppLocale.instance.isArabic;
    final title =
        message.data[arabic ? 'title_ar' : 'title_en'] ??
        message.notification?.title ??
        '';
    final body =
        message.data[arabic ? 'body_ar' : 'body_en'] ??
        message.notification?.body ??
        '';
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null || (title.isEmpty && body.isEmpty)) return;

    final open = openForNotification(
      relatedEntityType: message.data['related_entity_type'],
      type: message.data['type'],
      destination: message.data['destination'],
      relatedEntityId: message.data['related_entity_id'],
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(
            [title, body].where((part) => part.isNotEmpty).join(' — '),
          ),
          action: open == null
              ? null
              : SnackBarAction(
                  label: S.open,
                  onPressed: () => rootNavigatorKey.currentState?.pushNamed(
                    open.route,
                    arguments: open.entityId,
                  ),
                ),
        ),
      );
  }
}
