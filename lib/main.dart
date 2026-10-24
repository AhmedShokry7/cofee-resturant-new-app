import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/di/app_providers.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/theme_class.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // A release build has no debugger attached, so an uncaught framework error
  // would otherwise disappear without a trace. Both handlers log through
  // [debugPrint] (which stays in release logs) so a crash on a real device can
  // be diagnosed from `adb logcat` instead of guessing.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logRelease('FlutterError', details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _logRelease('UncaughtError', error.toString(), stack);
    return true;
  };

  // Locale first: everything else renders through it.
  await _guard('AppLocale.init', () => AppLocale.instance.initialize());

  // Android uses generated Firebase options; iOS uses its native GoogleService-Info.plist.
  // A missing platform setup is logged but never blocks the app from starting.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await _guard(
      'Firebase.init',
      () => Firebase.initializeApp(
        options: defaultTargetPlatform == TargetPlatform.android
            ? DefaultFirebaseOptions.currentPlatform
            : null,
      ),
    );
  }

  // The backend is optional at startup. A failure must not stop the app: the
  // providers fall back to their offline implementations. The connection is
  // retried a few times, because a phone that wakes up without a network
  // would otherwise stay without a backend for the whole session.
  await _guard('Supabase.init', () => SupabaseService.ensureReady());

  // The push is set up after the backend, because the token of the device is
  // registered with it. The tap handler is attached inside the setup, so a
  // tap that opens the app from a cold start is not lost.
  await _guard(
    'Push.start',
    () => PushService.start(onOpened: _handlePushOpened),
  );

  // The saved session decides where the app resumes. Reading it can fail on a
  // locked profile, and the app still has to start.
  final session = const SessionRepository();
  String? currentRoute;
  var onboardingDone = false;
  await _guard('Session.read', () async {
    currentRoute = await session.currentRoute();
    onboardingDone = await session.hasCompletedOnboarding();
  });

  // Preview mode: allow the admin dashboard to override design tokens via the
  // query string without touching published configuration.
  try {
    final params = Uri.base.queryParameters;
    if (params['preview'] == '1') {
      Color? parse(String? hex) {
        if (hex == null || hex.isEmpty) return null;
        final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
        if (value == null) return null;
        return Color(value | 0xFF000000);
      }

      final primary = parse(params['primary']);
      if (primary != null) AppColor.primaryColor = primary;
      final secondary = parse(params['secondary']);
      if (secondary != null) AppColor.secondryColor = secondary;
      final background = parse(params['background']);
      if (background != null) {
        // background is not a separate token; keep for future use.
      }
      final surface = parse(params['surface']);
      if (surface != null) AppColor.surfaceColor = surface;
    }
  } catch (_) {}
  runApp(MyApp(currentRoute: currentRoute, onboardingDone: onboardingDone));
}

/// Runs a startup step and swallows its failure.
///
/// Startup must always reach `runApp`; a step that fails is logged and the app
/// continues with whatever state is available.
Future<void> _guard(String label, Future<void> Function() action) async {
  try {
    await action();
  } catch (error, stackTrace) {
    _logRelease(label, error.toString(), stackTrace);
  }
}

/// Opens the notifications when the customer taps a push.
///
/// A tap that opens the app from a cold start arrives before there is a
/// navigator to push a route on, so the route waits in [PushService] until the
/// main page takes it. A tap while the app is already open on the main page
/// opens the screen right away.
void _handlePushOpened(RemoteMessage message) {
  final relatedType = message.data['related_entity_type'];
  final route = switch (relatedType) {
    'order' => OrdersPage.routeName,
    'subscription' => SubscriptionDetailsPage.routeName,
    _ => NotificationsPage.routeName,
  };
  final navigator = rootNavigatorKey.currentState;
  if (navigator != null) {
    navigator.pushNamed(route);
    return;
  }
  PushService.setPendingRoute(route);
}

/// Logs a startup failure where a release build can still show it.
///
/// `debugPrint` is not stripped in release mode, so the line reaches
/// `adb logcat` and a crash on a real device can be read from there.
void _logRelease(String label, String message, StackTrace? stackTrace) {
  debugPrint('[$label] $message');
  if (stackTrace != null) {
    debugPrintStack(stackTrace: stackTrace, maxFrames: 12);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.currentRoute, this.onboardingDone = false});

  final String? currentRoute;

  /// Whether the customer already finished the onboarding.
  final bool onboardingDone;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<RemoteMessage>? _foregroundPushSubscription;

  @override
  void initState() {
    super.initState();
    _foregroundPushSubscription = PushService.onForegroundMessage.listen(
      _showForegroundPush,
    );
  }

  void _showForegroundPush(RemoteMessage message) {
    final arabic = AppLocale.instance.isArabic;
    final title =
        message.data[arabic ? 'title_ar' : 'title_en'] ??
        message.notification?.title ??
        '';
    final body =
        message.data[arabic ? 'body_ar' : 'body_en'] ??
        message.notification?.body ??
        '';
    if (!mounted || (title.isEmpty && body.isEmpty)) return;
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            [title, body].where((part) => part.isNotEmpty).join(' — '),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _foregroundPushSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return AppProviders(
          child: AnimatedBuilder(
            animation: AppLocale.instance,
            builder: (context, _) => MaterialApp(
              title: S.appName,
              locale: AppLocale.instance.locale,
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              debugShowCheckedModeBanner: false,
              theme: ThemeClass.light(isArabic: AppLocale.instance.isArabic),
              builder: (context, child) => Directionality(
                textDirection: AppLocale.instance.textDirection,
                child: child ?? const SizedBox.shrink(),
              ),
              navigatorKey: rootNavigatorKey,
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              // The assistant FAB is owned by the Home page scaffold, not by
              // a global overlay, so it can never duplicate or leak onto
              // other screens.
              navigatorObservers: [AppRouteObserver.instance],
              // The splash owns the brand mark because the Android 12+ system
              // splash clamps its icon to a fixed circle. It hands over to the
              // saved entry route once it is done.
              initialRoute: SplashView.routeName,
              onGenerateRoute: AppRouteGenerator.onGenerateRoute,
              routes: {
                SplashView.routeName: (context) => SplashView(
                  targetRoute: AppRoutes.initialRouteName(
                    widget.currentRoute,
                    onboardingDone: widget.onboardingDone,
                  ),
                ),
                ...AppRoutes.routes,
              },
            ),
          ),
        );
      },
    );
  }
}
