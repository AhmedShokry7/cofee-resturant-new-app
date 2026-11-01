import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/welcome/presentation/manager/welcome/welcome_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/wavy_container.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_hero_image.dart';
import 'package:new_coffee/features/welcome/presentation/views/welcome_view.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

import 'support/pump_harness.dart';

/// The session with its writes counted, so a tap can be told apart from two.
class _CountingSession extends SessionRepository {
  int seenWrites = 0;

  @override
  Future<bool> markOnboardingSeenConfirmed() async {
    seenWrites++;
    // Yield once, so a second tap lands while this write is still in flight.
    await Future<void>.delayed(Duration.zero);
    return super.markOnboardingSeenConfirmed();
  }
}

class _FailingSession extends SessionRepository {
  @override
  Future<bool> markOnboardingSeenConfirmed() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('what the welcome screen decides', () {
    test('the marker lands before the next screen is offered', () async {
      final cubit = WelcomeCubit();
      addTearDown(cubit.close);

      await cubit.startOnboarding();

      expect(cubit.state.nextRoute, OnBoardingView.routeName);
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.onBoardingRoute,
        reason: 'the screen may only be replaced once the marker is stored',
      );
    });

    test('one tap writes once, however often it is pressed', () async {
      final session = _CountingSession();
      final cubit = WelcomeCubit(session: session);
      addTearDown(cubit.close);

      await Future.wait([cubit.startOnboarding(), cubit.startOnboarding()]);

      expect(session.seenWrites, 1);
    });

    test(
      'a write that cannot be confirmed keeps the customer in place',
      () async {
        final cubit = WelcomeCubit(session: _FailingSession());
        addTearDown(cubit.close);

        await cubit.startOnboarding();

        expect(cubit.state.nextRoute, isNull);
        expect(cubit.state.saveFailed, isTrue);
        expect(
          await const SessionRepository().currentRoute(),
          isNot(AppConstant.onBoardingRoute),
        );
      },
    );

    test('the button is busy while the write is in flight', () async {
      final cubit = WelcomeCubit(session: _CountingSession());
      addTearDown(cubit.close);

      final pending = cubit.startOnboarding();
      expect(cubit.state.isStarting, isTrue);

      await pending;
      expect(cubit.state.isStarting, isFalse);
    });
  });

  group('the welcome screen itself', () {
    Future<void> pumpWelcome(
      WidgetTester tester, {
      Size logicalSize = phoneViewport,
    }) async {
      // The screen sizes the design was drawn for; the default 800x600 test
      // surface is not a phone this layout was made for.
      tester.view.physicalSize = logicalSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: WelcomePage.routeName,
          routes: {
            WelcomePage.routeName: (context) => const WelcomePage(),
            // The onboarding screen needs the whole provider tree; the flow
            // only cares that this route took the screen.
            OnBoardingView.routeName: (context) =>
                const Scaffold(body: Text('onboarding-stub')),
          },
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('starting takes the customer to the onboarding', (
      tester,
    ) async {
      await pumpWelcome(tester);

      await tester.tap(find.text(S.letsGetStarted));
      await tester.pumpAndSettle();

      expect(find.text('onboarding-stub'), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.onBoardingRoute,
      );
    });

    testWidgets('the copy and the photograph are both on screen', (
      tester,
    ) async {
      await pumpWelcome(tester);

      expect(find.text(S.welcomeDescription), findsOneWidget);
      // The headline is one rich paragraph, so it is looked for whole.
      expect(find.text('${S.yourCoffee} ${S.yourMoment}'), findsOneWidget);
      expect(find.byType(WelcomeHeroImage), findsOneWidget);
      expect(find.byType(WavyContainer), findsOneWidget);
      // One frame only: the screen used to wrap its body in a second Scaffold.
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('the way forward stays on screen in every language', (
      tester,
    ) async {
      // English needs more height than Arabic for the same copy, and the
      // design size is the shortest screen the design was drawn for. The
      // button must survive that, because it is the only way off the screen.
      await pumpWelcome(tester);

      final buttonRect = tester.getRect(find.byType(CustomBtn));
      expect(buttonRect.top, greaterThanOrEqualTo(0));
      expect(buttonRect.bottom, lessThanOrEqualTo(phoneViewport.height));
    });
  });
}
