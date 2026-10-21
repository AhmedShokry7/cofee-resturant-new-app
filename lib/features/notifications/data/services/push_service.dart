import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/repositories/push_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;

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
/// The permission is asked once per install and only for a signed-in
/// customer: a guest has no notifications to receive, and asking twice is
/// noise.
class PushService {
  PushService._();

  /// The platform the tokens of this app belong to.
  static const String platform = 'android';

  /// Remembers that the system prompt was already shown, so the customer is
  /// not asked again on every launch.
  static const String _promptedFlag = 'push_permission_prompted_v1';

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

  /// The customer the permission was already asked for.
  ///
  /// The permission belongs to the device, but the registration belongs to
  /// the customer, so it is asked once for every customer that signs in.
  static String? _enabledUserId;

  /// The route a tapped notification asks for, waiting for the app to be
  /// ready to show it.
  ///
  /// A tap that opens the app from a cold start arrives before the first
  /// frame is drawn, so there is no navigator to push a route on yet. The
  /// route waits here until the main page takes it.
  static String? _pendingRoute;

  /// Remembers the route of a tapped notification.
  static void setPendingRoute(String route) {
    _pendingRoute = route;
  }

  /// The route of a tapped notification, and forgets it.
  static String? takePendingRoute() {
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
      await _markPrompted();
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
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _started = true;

    final pushRepository = repository ?? const PushRepositoryImpl();

    try {
      FirebaseMessaging.onBackgroundMessage(pushMessagingBackgroundHandler);

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
    // Every event that carries a session counts, not only the sign-in: the
    // session of a returning customer is restored after the app started, and
    // that is the moment the permission has to be asked.
    _enabledUserId = userId;
    await _enable(const PushRepositoryImpl());
  }

  /// Asks for the permission and registers the token.
  ///
  /// The permission is asked once per install. When the customer had already
  /// answered it, the choice on the server is left alone: a customer who
  /// switched the notifications off in the settings must not have them
  /// switched on again by a new sign-in.
  static Future<void> _enable(PushRepository repository) async {
    try {
      final askedBefore = await _wasPrompted();
      final settings = await FirebaseMessaging.instance.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) {
        await _markPrompted();
        return;
      }

      // The token of the device. The newer API of the plugin reports the
      // installation id of the app instance, which only arrives when the
      // device registers itself. The token of getToken() is what the server
      // sends to, and it is there on every launch.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _token = token;
      await _registerToken(token, repository);

      if (!askedBefore) {
        // The customer answered the prompt for the first time, so the push is
        // what they asked for.
        await repository.setPushEnabled(true);
      }
      await _markPrompted();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] enable failed: $error');
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

  static Future<bool> _wasPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_promptedFlag) ?? false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] read flag failed: $error');
      }
      return false;
    }
  }

  static Future<void> _markPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_promptedFlag, true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[PushService] write flag failed: $error');
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
