import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/di/app_providers.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/app_route_observer.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/theme_class.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_fab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
          child: MaterialApp(
            title: 'New Coffee',
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
        );
      },
    );
  }
}
