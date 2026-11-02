import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/login_page_body.dart';

import 'support/pump_harness.dart';

/// The screens are looked at and one link is followed; nothing is submitted, so
/// the repository only has to exist.
class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was called');
}

/// What the sign-up screen was handed when it was opened.
Object? _received = _nothing;
const Object _nothing = Object();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _received = _nothing;
  });

  /// The sign-in screen, pushed the way the checkout guard pushes it: with the
  /// page to go back to as the route argument.
  Future<void> pumpLogin(
    WidgetTester tester, {
    TextDirection direction = TextDirection.rtl,
  }) async {
    tester.view.physicalSize = phoneViewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: child ?? const SizedBox.shrink(),
        ),
        routes: {
          '/asked': (context) => BlocProvider<AuthCubit>(
            create: (context) => AuthCubit(_UnusedAuthRepository()),
            child: const Scaffold(body: LoginPageBody()),
          ),
          SignUpPage.routeName: (context) {
            _received = ModalRoute.of(context)?.settings.arguments;
            return const Scaffold(body: Center(child: Text('sign up here')));
          },
        },
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context)
                  .pushNamed('/asked', arguments: 'checkoutRoute');
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> semanticsLabels(WidgetTester tester) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .map((widget) => widget.properties.label ?? '')
      .toList();

  group('between the two forms', () {
    testWidgets('the page that asked for sign-in is passed on to sign-up', (
      tester,
    ) async {
      await pumpLogin(tester);

      await tester.tap(find.text(S.signUp));
      await tester.pumpAndSettle();

      expect(
        _received,
        'checkoutRoute',
        reason:
            'a customer who creates an account instead of signing in was '
            'asked to authenticate by the checkout, and belongs back there',
      );
    });
  });

  group('reading direction', () {
    testWidgets('forgot-password sits at the end of the line in Arabic', (
      tester,
    ) async {
      await pumpLogin(tester);

      final forgot = tester.getRect(find.text(S.forgotPasswordQ));
      final screen = tester.getRect(find.byType(LoginPageBody));

      expect(
        forgot.right - screen.left,
        lessThan(screen.width - forgot.left),
        reason:
            'in a right-to-left screen the trailing link belongs on the '
            'left edge, where the reading line ends',
      );
    });

    testWidgets('and on the right in English', (tester) async {
      await pumpLogin(tester, direction: TextDirection.ltr);

      final forgot = tester.getRect(find.text(S.forgotPasswordQ));
      final screen = tester.getRect(find.byType(LoginPageBody));

      expect(screen.right - forgot.right, lessThan(forgot.left - screen.left));
    });
  });

  group('the provider buttons', () {
    testWidgets('each one says out loud which account it uses', (tester) async {
      await pumpLogin(tester);

      expect(
        semanticsLabels(tester),
        containsAll(<String>[
          S.continueWithGoogle,
          S.continueWithFacebook,
          S.continueWithApple,
        ]),
        reason:
            'a circle with a logo in it is an unnamed image to a screen '
            'reader',
      );
    });

    testWidgets('each one is a real button, with ink and a shape', (
      tester,
    ) async {
      await pumpLogin(tester);

      for (final icon in [AppIcons.google, AppIcons.facebook, AppIcons.apple]) {
        expect(
          find.descendant(
            of: find.byType(AuthSocialLogin),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(of: find.byIcon(icon), matching: find.byType(InkWell)),
          findsOneWidget,
          reason: '$icon is tappable, so it presses visibly',
        );
      }
    });
  });
}
