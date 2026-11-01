import 'package:flutter/widgets.dart';

import 'package:new_coffee/app.dart';
import 'package:new_coffee/core/startup/app_bootstrap.dart';

/// The entry point.
///
/// Only two things happen here: the binding is taken, then [bootstrapApp]
/// brings up the services the app runs on and says where to resume. A step
/// that fails is logged there and never stops the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startup = await bootstrapApp();
  runApp(
    MyApp(
      currentRoute: startup.currentRoute,
      onboardingDone: startup.onboardingDone,
    ),
  );
}
