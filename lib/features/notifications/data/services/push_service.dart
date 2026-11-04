import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/repositories/push_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

/// Receives the push that Android hands to the app while it is in the
/// background.
///
/// There is nothing to do here. The notification itself is already stored in
/// the database, and the app reads it from there when it opens, so the
/// background isolate only needs an entry point for the Firebase SDK.
@pragma('vm:entry-point')
Future<void> pushMessagingBackgroundHandler(RemoteMessage message) async {}

/// The push notifications of the app.
///
/// Three things happen here:
///
///   * the token of the device is registered with the server, so the customer
///     receives the notifications on every phone they sign in on;
///   * a message that arrives while the app is open is handed to the
///     listener, which refreshes the list of the notifications;
///   * a message the customer taps is handed to the listener, which opens the
///     screen the notification belongs to.
///
/// Permission is requested only after the customer turns notifications on
/// from the in-app settings. A guest is never prompted.
class PushService {
  PushService._();

  /// The platform the tokens of this app belong to.
  static String get platform => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'unknown',
  };

  static final StreamController<RemoteMessage> _foregroundMessages =
      StreamController<RemoteMessage>.broadcast();
  static final StreamController<RemoteMessage> _openedMessages =
      StreamController<RemoteMessage>.broadcast();

  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<AuthState>? _authSubscription;

  static bool _started = false;
  static String? _token;

  /// The customer whose token registration was most recently attempted.
  ///
  /// Permission belongs to the device, but the token registration belongs to
  /// the signed-in customer.
  static String? _enabledUserId;

  /// The destination a tapped notification asked for, waiting for the app to be
  /// ready to show it.
  ///
  /// A tap that opens the app from a cold start arrives before the first
  /// frame is drawn, so there is no navigator to push a route on yet. The
  /// destination waits here until the main page takes it, and it keeps the
  /// record the message names so the wait does not cost the customer the order
  /// they were sent to.
  static NotificationOpen? _pendingRoute;

  /// Remembers the destination of a tapped notification.
  static void setPendingRoute(NotificationOpen route) {
    _pendingRoute = route;
  }

  /// The destination of a tapped notification, and forgets it.
  static NotificationOpen? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Turns the push on or off for the customer.
  ///
  /// Turning it on needs the permission of the system: without it the server
  /// would deliver nothing. Turning it off only changes the switch on the
  /// server, the token stays so the customer can switch it on again without
  /// asking the system a second time.
  static Future<bool> setEnabled(
    bool enabled, {
    PushRepository? repository,
  }) async {
    final pushRepository = repository ?? const PushRepositoryImpl();
    try {
      if (!enabled) {
        await pushRepository.setPushEnabled(false);
        return false;
      }

      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;

      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        await _registerToken(token, pushRepository);
      }
      await pushRepository.setPushEnabled(true);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] setEnabled failed: $error');
      }
      return false;
    }
  }

  /// A message that arrived while the app was in the foreground.
  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessages.stream;

  /// A message the customer tapped.
  static Stream<RemoteMessage> get onOpenedMessage => _openedMessages.stream;

  /// The token of this device, once it is known.
  static String? get token => _token;

  /// Starts the push.
  ///
  /// Does nothing on a platform without a Firebase app, and never throws:
  /// a push that cannot be set up must not stop the app from starting.
  ///
  /// [onOpened] is called for every message the customer taps, including the
  /// one that opened the app from a cold start.
  static Future<void> start({
    PushRepository? repository,
    void Function(RemoteMessage message)? onOpened,
  }) async {
    if (_started) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _started = true;

    final pushRepository = repository ?? const PushRepositoryImpl();

    try {
      FirebaseMessaging.onBackgroundMessage(pushMessagingBackgroundHandler);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              // The app displays its own foreground banner.
              alert: false,
              badge: true,
              sound: false,
            );
      }

      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        _foregroundMessages.add(message);
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        _openedMessages.add(message);
        onOpened?.call(message);
      });
      // A new token after the one the server knows: the old row is replaced
      // by the server, so the customer keeps receiving the notifications.
      // ignore: deprecated_member_use
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) {
        unawaited(_registerToken(token, pushRepository));
      });

      // A message that opened the app from a cold start.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _openedMessages.add(initial);
        onOpened?.call(initial);
      }

      if (SupabaseService.isReady) {
        _authSubscription = SupabaseService.client.auth.onAuthStateChange
            .listen(_onAuthStateChanged);
        final currentUserId = SupabaseService.client.auth.currentUser?.id;
        if (currentUserId != null) {
          _enabledUserId = currentUserId;
          await _enable(pushRepository);
        }
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[PushService] start failed: $error');
        debugPrintStack(stackTrace: stackTrace, maxFrames: 8);
      }
    }
  }

  /// Stops the push and closes the streams.
  ///
  /// Only used by the tests: the app keeps the push until it is closed.
  @visibleForTesting
  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    await _openedSubscription?.cancel();
    _openedSubscription = null;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _foregroundMessages.close();
    await _openedMessages.close();
    _started = false;
  }

  /// Turns the push off for this device.
  ///
  /// Called before the session ends, because the server can only remove a
  /// token that still belongs to the customer who is signing out.
  static Future<void> unregister({PushRepository? repository}) async {
    final token = _token;
    if (token == null) return;
    try {
      await (repository ?? const PushRepositoryImpl()).unregisterToken(token);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] unregister failed: $error');
      }
    }
  }

  static Future<void> _onAuthStateChanged(AuthState auth) async {
    if (auth.event == AuthChangeEvent.signedOut) {
      _enabledUserId = null;
      await unregister();
      return;
    }
    final userId = auth.session?.user.id;
    if (userId == null || userId == _enabledUserId) return;
    // Restore the token registration when a returning customer session loads.
    // This only checks existing permission and never opens the OS prompt.
    _enabledUserId = userId;
    await _enable(const PushRepositoryImpl());
  }

  /// Registers an already-authorized device without prompting on sign-in.
  /// The customer explicitly grants notification permission from the settings
  /// screen; logging in must never unexpectedly open an OS permission dialog.
  static Future<void> _enable(PushRepository repository) async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return;

      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      await _registerToken(token, repository);
      await adoptGrantedPush(repository);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] enable failed: $error');
      }
    }
  }

  /// Opens the server switch of a customer who already allowed notifications on
  /// the phone and has never been asked.
  ///
  /// The database stops every message of a customer whose preferences row is
  /// missing, and this app only wrote that row when the customer pressed the
  /// switch in the app. A device that granted the system permission and never
  /// reached the switch therefore received nothing. `updated_at` comes back null
  /// only in the answer the server synthesises for a customer who has never
  /// chosen, so a switch the customer turned off is respected and never opened
  /// again from here.
  @visibleForTesting
  static Future<void> adoptGrantedPush(PushRepository repository) async {
    try {
      final switches = await repository.preferences();
      if (switches.chosen || switches.pushEnabled) return;
      await repository.setPreferences(pushEnabled: true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] push adoption failed: $error');
      }
    }
  }

  static Future<void> _registerToken(
    String token,
    PushRepository repository,
  ) async {
    try {
      await repository.registerToken(
        token: token,
        platform: platform,
        appVersion: AppVersion.current,
        locale: AppLocale.instance.isArabic ? 'ar' : 'en',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] register failed: $error');
      }
    }
  }
}

/// The version of the build, sent with the token.
///
/// It answers the question "which build registered this token", which is the
/// first question when a customer says the notifications do not arrive. Keep
/// it in step with the version in pubspec.yaml.
class AppVersion {
  AppVersion._();

  static const String current = '1.0.0';
}
