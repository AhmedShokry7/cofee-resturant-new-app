import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/login_page_body.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/sign_up_page_body.dart';
import 'package:new_coffee/features/on_boarding/presentation/views/on_boarding_view.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

import 'support/pump_harness.dart';

/// These screens are looked at, never pressed, so the repository is only asked
/// to exist. A call it does not answer is reported instead of quietly answered.
class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was called');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The box the customer actually hits: the `SkipBtn` element is the alignment
  /// it lives in, which fills the whole screen.
  Finder skipButton() => find.descendant(
    of: find.byType(SkipBtn),
    matching: find.byType(TextButton),
  );

  Future<Rect> skipRectOn(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = phoneViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(screen);
    await tester.pumpAndSettle();
    return tester.getRect(skipButton());
  }

  Widget authScreen(Widget body) => BlocProvider<AuthCubit>(
    create: (context) => AuthCubit(_UnusedAuthRepository()),
    child: MaterialApp(home: Scaffold(body: body)),
  );

  Widget onBoardingScreen() => MaterialApp(home: const OnBoardingView());

  group('the one skip control', () {
    testWidgets(
      'the intro slides, sign-in and sign-up put it on the same box',
      (tester) async {
        final slides = await skipRectOn(tester, onBoardingScreen());
        final signIn = await skipRectOn(
          tester,
          authScreen(const LoginPageBody()),
        );
        final signUp = await skipRectOn(
          tester,
          authScreen(const SignUpPageBody()),
        );

        expect(
          signIn,
          slides,
          reason:
              'sign-in moves the control off the corner '
              'the intro slides set',
        );
        expect(
          signUp,
          slides,
          reason:
              'sign-up moves the control off the corner '
              'the intro slides set',
        );
      },
    );

    testWidgets('it keeps the inset and the tappable box the theme promises', (
      tester,
    ) async {
      final box = await skipRectOn(tester, authScreen(const LoginPageBody()));

      expect(box.top, AppDimensions.skipInset);
      expect(
        box.width,
        greaterThanOrEqualTo(AppDimensions.tapTargetMin),
        reason: 'a short word still has to be a hittable target',
      );
      expect(box.height, greaterThanOrEqualTo(AppDimensions.tapTargetMin));
    });

    testWidgets('it stays on screen while the form scrolls', (tester) async {
      for (final body in <Widget>[
        const LoginPageBody(),
        const SignUpPageBody(),
      ]) {
        await skipRectOn(tester, authScreen(body));

        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(SkipBtn),
          ),
          findsNothing,
          reason:
              'a way out that scrolls away with a long form is not a way '
              'out; the control belongs over the scroller, not inside it',
        );
      }
    });

    testWidgets('the word is underlined by the text engine, not by a rule', (
      tester,
    ) async {
      await skipRectOn(tester, authScreen(const LoginPageBody()));

      final label = tester.widget<Text>(find.text(S.skip));
      expect(label.style?.decoration, TextDecoration.underline);
      expect(
        find.descendant(
          of: find.byType(SkipBtn),
          matching: find.byType(Container),
        ),
        findsNothing,
        reason:
            'the underline used to be a box capped at a fixed width, so it '
            'stuck out past the word it was meant to sit under',
      );
    });
  });
}
