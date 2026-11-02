import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/login_page_body.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

import 'support/pump_harness.dart';

const _user = AuthUser(id: 'u-1', name: 'Ahmed', email: 'a@b.com');

/// A backend that answers whatever the test is asking about, and nothing else.
class _ScriptedAuthRepository implements AuthRepository {
  _ScriptedAuthRepository({this.failure, this.verificationPending = false});

  /// Thrown by every call, so a test can watch what a failed provider leaves
  /// behind and then clear it to prove a retry is still possible.
  Object? failure;
  final bool verificationPending;

  int signOutCalls = 0;

  @override
  bool get lastSignUpNeedsEmailConfirmation => verificationPending;

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _answer();

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) => _answer();

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) => _answer();

  @override
  Future<void> sendEmailCode({required String email}) async {}

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) => _answer();

  Future<AuthUser> _answer() async {
    final error = failure;
    if (error != null) throw error;
    return _user;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<AuthUser> signInWithGoogle() => _answer();
  @override
  Future<AuthUser> signInWithFacebook() => _answer();
  @override
  Future<AuthUser> signInWithApple() => _answer();
  @override
  Future<void> sendPhoneCode({required String phone}) async {}
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
  @override
  Future<void> resetPassword({required String newPassword}) async {}
  @override
  Future<AuthUser?> currentUser() async => _user;
  @override
  Future<AuthUser> updateProfile({required String fullName, String? phone}) =>
      _answer();
  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

/// A store that reports every write as lost.
class _UnconfirmedSession extends SessionRepository {
  const _UnconfirmedSession();

  @override
  Future<bool> markAuthenticatedConfirmed() async => false;

  @override
  Future<bool> markSignedOutConfirmed() async => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('who writes the session marker', () {
    test('a sign-in writes it before the screen is told', () async {
      final cubit = AuthCubit(_ScriptedAuthRepository());
      addTearDown(cubit.close);

      await cubit.signIn(email: 'a@b.com', password: 'secret');

      expect(cubit.state, isA<AuthSuccess>());
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.homeRoute,
      );
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });

    test('a phone verification writes it too', () async {
      final cubit = PhoneAuthCubit(_ScriptedAuthRepository());
      addTearDown(cubit.close);

      await cubit.verifyCode(phone: '+201000000000', code: '123456');

      expect(cubit.state, isA<PhoneAuthSuccess>());
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.homeRoute,
      );
    });

    test('skipping writes the same marker as signing in', () async {
      final cubit = AuthCubit(_ScriptedAuthRepository());
      addTearDown(cubit.close);

      await cubit.skipAuthentication();

      expect(cubit.state, isA<AuthSkipped>());
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.homeRoute,
      );
      expect(await const SessionRepository().hasCompletedOnboarding(), isTrue);
    });

    test('an address that must confirm its email leaves no marker', () async {
      final cubit = AuthCubit(
        _ScriptedAuthRepository(verificationPending: true),
      );
      addTearDown(cubit.close);

      await cubit.signUp(name: 'Ahmed', email: 'a@b.com', password: 'secret');

      expect(cubit.state, isA<AuthEmailConfirmationRequired>());
      expect(
        await const SessionRepository().currentRoute(),
        isNull,
        reason: 'an unconfirmed address is not a session worth recording',
      );
    });

    test('a marker that will not land still lets the customer in', () async {
      final cubit = AuthCubit(
        _ScriptedAuthRepository(),
        session: _UnconfirmedSession(),
      );
      addTearDown(cubit.close);

      await cubit.signIn(email: 'a@b.com', password: 'secret');

      expect(
        cubit.state,
        isA<AuthSuccess>(),
        reason:
            'the provider signed the customer in; a storage failure is '
            'not their mistake and must not strand them outside the store',
      );
    });
  });

  group('sign out', () {
    test('a successful sign-out clears the stored route', () async {
      await const SessionRepository().markAuthenticatedConfirmed();
      final cubit = AuthCubit(_ScriptedAuthRepository());
      addTearDown(cubit.close);

      await cubit.signOut();

      expect(cubit.state, isA<AuthSignedOut>());
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.authRoute,
      );
    });

    test('a failed sign-out leaves the route and says so', () async {
      await const SessionRepository().markAuthenticatedConfirmed();
      final repository = _ScriptedAuthRepository(
        failure: StateError('sign out failed'),
      );
      final cubit = AuthCubit(repository);
      addTearDown(cubit.close);

      await cubit.signOut();

      expect(cubit.state, isA<AuthFailure>());
      expect(
        (cubit.state as AuthFailure).message,
        S.logoutFailed,
        reason:
            'the customer is still signed in, so the screen must not '
            'claim a sign-out',
      );
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.homeRoute,
      );
      expect(repository.signOutCalls, 1);

      // A later attempt is still possible: the guard is the cubit's own
      // in-flight state, not a latch.
      repository.failure = null;
      await cubit.signOut();

      expect(cubit.state, isA<AuthSignedOut>());
      expect(repository.signOutCalls, 2);
    });

    test('one sign-out at a time', () async {
      final repository = _ScriptedAuthRepository();
      final cubit = AuthCubit(repository);
      addTearDown(cubit.close);

      final first = cubit.signOut();
      await cubit.signOut();
      await first;

      expect(repository.signOutCalls, 1);
    });
  });

  group('the screen only reacts', () {
    Future<void> pumpLogin(WidgetTester tester, AuthCubit cubit) async {
      // A phone-sized viewport: the sign-in body scrolls, and the default test
      // window stretches it wide enough that the skip control lands where the
      // hit test cannot reach it.
      tester.view.physicalSize = phoneViewport * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            routes: {
              MainPage.routeName: (context) =>
                  const Scaffold(body: Text('home-stub')),
            },
            home: const Scaffold(body: LoginPageBody()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('skip hands the customer to the store, marker and all', (
      tester,
    ) async {
      final cubit = AuthCubit(_ScriptedAuthRepository());
      addTearDown(cubit.close);
      await pumpLogin(tester, cubit);

      expect(find.byType(SkipBtn), findsOneWidget);
      await tester.tap(find.text(S.skip));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppConstant.routesKey,
        ),
        AppConstant.homeRoute,
        reason:
            'the write belongs to the cubit, but the screen the customer '
            'ends up on is the proof it happened',
      );
    });
  });
}
