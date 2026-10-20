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
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';

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

  // The backend is optional at startup. A failure must not stop the app: the
  // providers fall back to their offline implementations.
  await _guard('Supabase.init', () => SupabaseService.init());

  // The saved session decides where the app resumes. Reading it can fail on a
  // locked profile, and the app still has to start.
  final session = const SessionRepository();
  String? currentRoute;
  var onboardingDone = false;
  await _guard('Session.read', () async {
    currentRoute = await session.currentRoute();
    onboardingDone = await session.hasCompletedOnboarding();
  });

  runApp(MyApp(currentRoute: currentRoute, onboardingDone: onboardingDone));
}

/// Runs a startup step and swallows its failure.
///
/// Startup must always reach `runApp`; a step that fails is logged and the app
/// continues with whatever state is available.
Future<void> _guard(
  String label,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error, stackTrace) {
    _logRelease(label, error.toString(), stackTrace);
  }
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

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.currentRoute, this.onboardingDone = false});

  final String? currentRoute;

  /// Whether the customer already finished the onboarding.
  final bool onboardingDone;

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
              theme: ThemeClass.light(
                isArabic: AppLocale.instance.isArabic,
              ),
              builder: (context, child) => Directionality(
                textDirection: AppLocale.instance.textDirection,
                child: child ?? const SizedBox.shrink(),
              ),
              navigatorKey: rootNavigatorKey,
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
                    currentRoute,
                    onboardingDone: onboardingDone,
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
