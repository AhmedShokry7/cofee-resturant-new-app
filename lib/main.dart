import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:new_coffee/app.dart';
import 'package:new_coffee/core/startup/app_bootstrap.dart';

/// The entry point.
///
/// Load the local session and the Supabase client, render the app, then bring
/// up Firebase and push delivery in the background.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startup = await bootstrapApp();
  runApp(
    MyApp(
      currentRoute: startup.currentRoute,
      onboardingDone: startup.onboardingDone,
    ),
  );
  unawaited(startBackgroundServices());
}
