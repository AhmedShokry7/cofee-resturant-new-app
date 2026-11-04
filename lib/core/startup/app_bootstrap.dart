import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/startup/preview_theme.dart';
import 'package:new_coffee/core/startup/startup_logging.dart';
import 'package:new_coffee/features/design/data/design_applier.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/notifications/data/services/push_tap_opener.dart';
import 'package:new_coffee/firebase_options.dart';

/// Where the app resumes: the route the customer left, and whether the
/// onboarding is already behind them.
typedef StartupTarget = ({String? currentRoute, bool onboardingDone});

/// Brings the app up, in the order its steps depend on.
///
/// Every step is guarded: none of them may stop the app from starting, because
/// each answers for a service the customer may not need in this session.
Future<StartupTarget> bootstrapApp() async {
  installErrorLogging();

  // Locale first: everything else renders through it.
  await runGuarded('AppLocale.init', () => AppLocale.instance.initialize());

  await _initFirebase();

  // The backend is optional at startup. A failure must not stop the app: the
  // providers fall back to their offline implementations. The connection is
  // retried a few times, because a phone that wakes up without a network
  // would otherwise stay without a backend for the whole session.
  await runGuarded('Supabase.init', () => SupabaseService.ensureReady());

  // The push is set up after the backend, because the token of the device is
  // registered with it. The tap handler is attached inside the setup, so a
  // tap that opens the app from a cold start is not lost.
  await runGuarded(
    'Push.start',
    () => PushService.start(onOpened: openPushRoute),
  );

  final target = await _readSavedSession();

  // التصميم الذي نشره الموظف يُقرأ قبل أول إطار، لا بعد الشاشة الأولى: إقلاع
  // يلوّن بعد ما ظهر ارتدادٌ يراه الزبون. لا صف منشور يعني طبقة محايدة، فلا
  // يتغيّر شيء عند بدء النظام.
  await runGuarded('Design.apply', () async {
    final design = await SupabaseDesignRepository().published();
    if (design == null) return;
    applyPublishedTheme(design.theme);
  });

  // Preview mode: allow the admin dashboard to override design tokens from the
  // query string without touching published configuration. Applied before the
  // first frame so the theme is built with the previewed colours.
  await runGuarded('PreviewTheme.apply', () async => applyPreviewTheme());

  return target;
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
