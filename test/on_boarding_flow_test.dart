import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/on_boarding/data/on_boarding_list.dart';
import 'package:new_coffee/features/on_boarding/presentation/manager/on_boarding/on_boarding_cubit.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_back_btn.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_dots.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_next_btn.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/widgets/on_boarding_slide.dart';

/// The session that cannot confirm a write, so the screen's reaction to a
/// storage that will not answer can be proven.
class _UnconfirmedSession extends SessionRepository {
  @override
  Future<bool> markOnboardingSkippedConfirmed() async => false;
}

/// The onboarding used to navigate from its cubit, keep a second copy of the
/// slide index, and leave its PageController alive. These tests lock the shape
/// it has now: the cubit reports where the customer is and which screen comes
/// next, and the screen only reacts.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  group('what the cubit decides', () {
    test('the last slide completes the onboarding instead of stepping', () async {
      final cubit = OnBoardingCubit();
      addTearDown(cubit.close);
      cubit.changePage(onBoardingSlides().length - 1);

      await cubit.next();

      expect(cubit.state, isA<OnBoardingCompleted>());
      expect(
        (cubit.state as OnBoardingCompleted).nextRoute,
        AuthPage.routeName,
      );
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.authRoute,
      );
    });

    test('skipping records the same marker and the same next screen', () async {
      final cubit = OnBoardingCubit();
      addTearDown(cubit.close);

      await cubit.complete();

      expect(
        (cubit.state as OnBoardingCompleted).nextRoute,
        AuthPage.routeName,
      );
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });

    test('a marker that will not land still lets the customer out', () async {
      // The deliberate opposite of the welcome screen: a tutorial must never
      // trap a customer because storage would not answer, while the welcome
      // screen is the one place the marker has to be sure of before it moves.
      final cubit = OnBoardingCubit(session: _UnconfirmedSession());
      addTearDown(cubit.close);

      await cubit.complete();

      expect(cubit.state, isA<OnBoardingCompleted>());
      expect(
        await const SessionRepository().hasCompletedOnboarding(),
        isFalse,
        reason: 'nothing was written, so the onboarding will simply show again',
      );
    });

    test('the slide index only moves when the PageView says it did', () async {
      final cubit = OnBoardingCubit();
      addTearDown(cubit.close);

      cubit.changePage(1);
      expect(cubit.currentPage, 1);
      expect(cubit.state, isA<OnBoardingPageChanged>());

      // The same page reported twice is not a change.
      cubit.changePage(1);
      expect(cubit.state, isA<OnBoardingPageChanged>());
      expect(cubit.currentPage, 1);
    });

    test('the first slide has nowhere to go back to', () async {
      final cubit = OnBoardingCubit();
      addTearDown(cubit.close);

      cubit.back();

      expect(cubit.currentPage, 0);
      expect(cubit.state, isA<OnBoardingInitial>());
    });

    test('closing the cubit disposes the controller it owns', () async {
      final cubit = OnBoardingCubit();

      await cubit.close();

      expect(() => cubit.pageController.addListener(() {}), throwsFlutterError);
    });
  });

  group('the onboarding screen', () {
    Future<void> pumpOnBoarding(WidgetTester tester) async {
      // The design size is the shortest screen this layout was made for, so a
      // slide that fits here fits anywhere.
      tester.view.physicalSize = AppConstant.designSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: AppConstant.designSize,
          builder: (context, _) => MaterialApp(
            initialRoute: OnBoardingView.routeName,
            routes: {
              OnBoardingView.routeName: (context) => const OnBoardingView(),
              // Sign-in needs the whole provider tree; the flow only cares
              // that this route took the screen.
              AuthPage.routeName: (context) =>
                  const Scaffold(body: Text('sign-in-stub')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> stepForward(WidgetTester tester) async {
      await tester.tap(find.byType(OnBoardingNextBtn));
      await tester.pumpAndSettle();
    }

    testWidgets('the first slide is on screen with one dot per slide', (
      tester,
    ) async {
      await pumpOnBoarding(tester);

      expect(find.byType(OnBoardingSlide), findsOneWidget);
      expect(find.text(S.onBoardingCatalogTitle), findsOneWidget);
      expect(find.byType(OnBoardingDots), findsOneWidget);
      expect(
        tester.widgetList(find.byType(AnimatedContainer)).length,
        onBoardingSlides().length,
      );
      // There is nothing behind the first slide.
      expect(find.byType(OnBoardingBackBtn), findsNothing);
    });

    testWidgets('the long language fits the same screen', (tester) async {
      // The English copy is longer than the Arabic it replaces, and the slide
      // box is a fixed share of the screen.
      AppLocale.instance.debugSet(AppLanguage.english);
      addTearDown(() => AppLocale.instance.debugSet(AppLanguage.arabic));

      await pumpOnBoarding(tester);

      expect(find.text(S.onBoardingCatalogTitle), findsOneWidget);
      expect(
        tester.getRect(find.byType(OnBoardingNextBtn)).bottom,
        lessThanOrEqualTo(AppConstant.designSize.height),
      );
    });

    testWidgets('stepping forward reveals the way back', (tester) async {
      await pumpOnBoarding(tester);

      await stepForward(tester);

      expect(find.byType(OnBoardingBackBtn), findsOneWidget);
      expect(find.text(S.onBoardingPaymentTitle), findsOneWidget);
    });

    testWidgets('the last forward step hands the customer to sign-in', (
      tester,
    ) async {
      await pumpOnBoarding(tester);

      for (var slide = 0; slide < onBoardingSlides().length; slide++) {
        await stepForward(tester);
      }

      expect(find.text('sign-in-stub'), findsOneWidget);
      expect(find.byType(OnBoardingView), findsNothing);
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });

    testWidgets('skipping leaves at once and never comes back', (
      tester,
    ) async {
      await pumpOnBoarding(tester);

      // The skip control is only as wide as its label.
      await tester.tap(find.text(S.skip));
      await tester.pumpAndSettle();

      expect(find.text('sign-in-stub'), findsOneWidget);
      expect(find.byType(OnBoardingView), findsNothing);
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });
  });
}
