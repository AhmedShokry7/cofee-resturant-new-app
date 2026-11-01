import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/di/app_providers.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/startup/app_bootstrap.dart';
import 'package:new_coffee/core/theme/theme_class.dart';
import 'package:new_coffee/features/notifications/presentation/manager/foreground_push_banners.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';

/// The root of the customer app: the providers, the language, the theme and
/// the routing. Everything that had to happen before this exists is in
/// [bootstrapApp].
class MyApp extends StatefulWidget {
  const MyApp({super.key, this.currentRoute, this.onboardingDone = false});

  /// The route the saved session left the customer on.
  final String? currentRoute;

  /// Whether the customer already finished the onboarding.
  final bool onboardingDone;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _foregroundBanners = ForegroundPushBanners();

  @override
  void initState() {
    super.initState();
    _foregroundBanners.start();
  }

  @override
  void dispose() {
    _foregroundBanners.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: AppConstant.designSize,
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
