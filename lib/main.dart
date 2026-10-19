import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/di/app_providers.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/theme_class.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocale.instance.initialize();

  // Fail fast: without --dart-define the providers below throw a clear
  // StateError instead of serving fabricated catalogue data.
  try {
    await SupabaseService.init();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[main] Supabase init failed, continuing with local data.');
      debugPrint('[main] $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  final currentRoute = await SharedPref.getValue(key: AppConstant.routesKey);
  runApp(MyApp(currentRoute: currentRoute));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.currentRoute});

  final String? currentRoute;

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
                  targetRoute: AppRoutes.initialRouteName(currentRoute),
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
