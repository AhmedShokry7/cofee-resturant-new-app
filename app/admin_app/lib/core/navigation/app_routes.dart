import 'package:flutter/material.dart';

import 'package:admin_app/features/startup/presentation/views/startup_page.dart';

class AppRoutes {
  const AppRoutes._();

  static Map<String, WidgetBuilder> get routes => <String, WidgetBuilder>{
        StartupPage.routeName: (BuildContext context) => const StartupPage(),
      };
}
