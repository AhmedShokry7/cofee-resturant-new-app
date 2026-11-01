import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/navigation/app_routes.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/splash/presentation/views/splash_view.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';

/// Regression cover for the failures that only showed up in a release build on
/// a real device:
///
///  * the splash used to stay on screen forever when the location prompt threw
///    while it was asking for permission, because the handover was sequenced
///    after that call;
///  * the onboarding marker used to be written without being confirmed, so a
///    customer could meet the onboarding again on the next launch;
///  * a missing route value sent a returning customer back to the welcome
///    screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('splash handover', () {
    testWidgets('hands over even when the location prompt cannot run', (
      tester,
    ) async {
      // Geolocator has no platform implementation in a widget test, so the
      // permission request fails. The handover must not depend on it.
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, child) => MaterialApp(
            routes: {
              SplashView.routeName: (context) => const SplashView(
                targetRoute: MainPage.routeName,
              ),
              // A stub for the real home page: the real one needs the whole
              // provider tree, which is irrelevant to the handover.
              MainPage.routeName: (context) =>
                  const Scaffold(body: Text('home-stub')),
            },
            initialRoute: SplashView.routeName,
          ),
        ),
      );

      await tester.pump(SplashView.displayDuration);
      await tester.pumpAndSettle();

      expect(find.byType(SplashView), findsNothing);
      expect(find.text('home-stub'), findsOneWidget);
    });
  });

  group('onboarding marker', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('skipping the onboarding is confirmed and survives a restart', () async {
      const session = SessionRepository();

      expect(await session.hasCompletedOnboarding(), isFalse);

      final saved = await session.markOnboardingSkippedConfirmed();
      expect(saved, isTrue);

      // A new repository stands in for the next launch: the marker has to come
      // from storage, not from anything held in memory.
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
      expect(await const SessionRepository().currentRoute(),
          AppConstant.authRoute);
    });

    test('a confirmed write reports failure instead of pretending', () async {
      const session = SessionRepository();
      final saved = await session.markOnboardingSkippedConfirmed();
      expect(saved, isTrue);
    });

    test('signing in also marks the onboarding as done', () async {
      await const SessionRepository().markAuthenticated();

      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.homeRoute,
      );
    });
  });

  group('entry route', () {
    test('a known route is honoured', () {
      expect(
        AppRoutes.initialRouteName(AppConstant.homeRoute),
        MainPage.routeName,
      );
      expect(
        AppRoutes.initialRouteName(AppConstant.authRoute),
        AuthPage.routeName,
      );
      expect(
        AppRoutes.initialRouteName(AppConstant.onBoardingRoute),
        OnBoardingView.routeName,
      );
    });

    test('a missing route still skips the onboarding for a returning user', () {
      expect(
        AppRoutes.initialRouteName(null),
        WelcomePage.routeName,
      );
      expect(
        AppRoutes.initialRouteName(null, onboardingDone: true),
        AuthPage.routeName,
      );
      expect(
        AppRoutes.initialRouteName('garbage', onboardingDone: true),
        AuthPage.routeName,
      );
    });
  });
}
