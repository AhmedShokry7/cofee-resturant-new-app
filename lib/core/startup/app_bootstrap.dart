import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/startup/preview_theme.dart';
import 'package:new_coffee/core/startup/startup_logging.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/notifications/data/services/push_tap_opener.dart';
import 'package:new_coffee/firebase_options.dart';

/// Where the app resumes: the route the customer left, and whether the
/// onboarding is already behind them.
typedef StartupTarget = ({String? currentRoute, bool onboardingDone});

/// Loads only the local state and backend client needed to compose the app.
///
/// Every step is guarded: none of them may stop the app from starting, because
/// each answers for a service the customer may not need in this session.
Future<StartupTarget> bootstrapApp() async {
  installErrorLogging();

  // Locale first: everything else renders through it.
  await runGuarded('AppLocale.init', () => AppLocale.instance.initialize());

  // Supabase.initialize restores the persisted session and creates the client;
  // retries here used to delay the first frame for up to six seconds on a
  // flaky connection. Individual repositories retry when they need the API.
  await runGuarded('Supabase.init', () async {
    await SupabaseService.init();
  });

  final target = await _readSavedSession();

  // Preview colours are local URL state and can be applied without waiting on
  // any network service.
  await runGuarded('PreviewTheme.apply', () async => applyPreviewTheme());

  return target;
}

/// Starts network and device services after the first frame is on screen.
/// DesignCubit loads the published design itself; this method only prepares
/// Firebase and push delivery, which are optional for rendering the catalogue.
Future<void> startBackgroundServices() async {
  await _initFirebase();
  await runGuarded('Crashlytics.configure', () async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
  });
  await runGuarded(
    'Push.start',
    () => PushService.start(onOpened: openPushRoute),
  );
}

/// A missing platform setup is logged but never blocks the app from starting.
Future<void> _initFirebase() async {
  if (kIsWeb) return;
  final hasNativeFirebase =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!hasNativeFirebase) return;

  // Android uses generated Firebase options; iOS uses its native
  // GoogleService-Info.plist.
  await runGuarded(
    'Firebase.init',
    () => Firebase.initializeApp(
      options: defaultTargetPlatform == TargetPlatform.android
          ? DefaultFirebaseOptions.currentPlatform
          : null,
    ),
  );
}

/// The saved session decides where the app resumes. Reading it can fail on a
/// locked profile, and the app still has to start.
Future<StartupTarget> _readSavedSession() async {
  const session = SessionRepository();
  String? currentRoute;
  var onboardingDone = false;
  await runGuarded('Session.read', () async {
    currentRoute = await session.currentRoute();
    onboardingDone = await session.hasCompletedOnboarding();
  });
  return (currentRoute: currentRoute, onboardingDone: onboardingDone);
}
