import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/di/app_providers.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/theme_class.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocale.instance.initialize();

  // Fail soft: without --dart-define the app still runs on the local mock
  // repositories, so the UI stays reviewable offline instead of crashing.
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
              title: 'New Coffee',
              locale: AppLocale.instance.locale,
              supportedLocales: const [Locale('ar'), Locale('en')],
              debugShowCheckedModeBanner: false,
              theme: ThemeClass.light(),
              navigatorKey: rootNavigatorKey,
              navigatorObservers: [AppRouteObserver.instance],
              builder: (context, child) => Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const AssistantFab(),
                ],
              ),
              initialRoute: AppRoutes.initialRouteName(currentRoute),
              onGenerateRoute: AppRouteGenerator.onGenerateRoute,
              routes: AppRoutes.routes,
            ),
          ),
        );
      },
    );
  }
}
