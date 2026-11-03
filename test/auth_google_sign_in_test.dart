import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get lastSignUpNeedsEmailConfirmation => false;

  int googleCalls = 0;
  AuthUser? googleUser;
  Object? googleError;
  Completer<void>? googleGate;

  int signInCalls = 0;
  AuthUser? signInUser;

  @override
  Future<AuthUser> signInWithGoogle() async {
    googleCalls++;
    final gate = googleGate;
    if (gate != null) {
      googleGate = null;
      await gate.future;
    }
    if (googleError != null) throw googleError!;
    return googleUser ?? const AuthUser(id: 'google-user');
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return signInUser ?? AuthUser(id: email, email: email);
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async => AuthUser(id: email, name: name, email: email);

  @override
  Future<AuthUser> signInWithFacebook() => Future.error(UnimplementedError());

  @override
  Future<AuthUser> signInWithApple() => Future.error(UnimplementedError());

  @override
  Future<void> sendPhoneCode({required String phone}) async {}

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async => AuthUser(id: phone);

  @override
  Future<void> sendEmailCode({required String email}) async {}

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async => AuthUser(id: email);

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> resetPassword({required String newPassword}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async => AuthUser(id: 'x', name: fullName, phone: phone);

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('AuthCubit Google sign-in', () {
    test('successful authentication emits AuthSuccess', () async {
      final repo = _FakeAuthRepository()
        ..googleUser = const AuthUser(id: 'g-1', email: 'a@b.com');
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthSuccess>());
      expect((cubit.state as AuthSuccess).user.id, 'g-1');
      expect(repo.googleCalls, 1);
    });

    test('cancellation emits AuthInitial without failure', () async {
      final repo = _FakeAuthRepository()
        ..googleError = const AuthException('google_sign_in_canceled');
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthInitial>());
    });

    test('provider error emits AuthFailure', () async {
      final repo = _FakeAuthRepository()
        ..googleError = const AuthException(
          'google_sign_in_failed: networkError',
        );
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      expect(
        AuthCubit.messageFor('google_sign_in_failed: networkError'),
        S.authGoogleUnavailable,
      );

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthFailure>());
      expect(
        (cubit.state as AuthFailure).message,
        S.authGoogleUnavailable,
        reason:
            'the token the repository now throws must not fall through to '
            'the generic sentence',
      );
    });

    test('a sign-in the service does not offer says so, and points elsewhere', () async {
      // Supabase refuses with this when the Google provider is switched off in
      // the dashboard, or when the ID token was minted by a client the project
      // does not know. Retrying cannot help, so the answer names the other door.
      expect(
        AuthCubit.messageFor('provider_not_enabled'),
        S.authProviderNotEnabled,
      );
      expect(
        AuthCubit.messageFor('Provider not enabled'),
        S.authProviderNotEnabled,
      );
      expect(S.authProviderNotEnabled, isNot(S.authFailed));
    });

    test('the Arabic sentence offers the door that works', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(S.authProviderNotEnabled, contains('البريد الإلكتروني'));
    });

    test(
      'a token our backend refuses is not sold to the customer as retryable',
      () {
        // Measured on emulator-5554 on 2026-11-02: GoTrue answered
        // `nonces mismatch` for an ID token Google had just issued, and the
        // screen said "Something went wrong signing in. Please try again." -
        // advice that cannot work, for a failure the customer did not cause.
        expect(
          AuthCubit.messageFor('nonces mismatch'),
          S.authProviderNotEnabled,
        );
        expect(
          AuthCubit.messageFor('Invalid audience'),
          S.authProviderNotEnabled,
        );
        expect(
          AuthCubit.messageFor('nonces mismatch'),
          isNot(S.authFailed),
          reason: 'the generic sentence is the defect this guards',
        );
      },
    );

    test('the exchange sends no client nonce', () {
      // The fix the record in tool/google_sign_in_setup.json explains: Google
      // ignores a nonce handed to GoogleSignIn.initialize on this path, so any
      // nonce the app sends makes GoTrue refuse the token. Re-adding one is a
      // regression, and no test of Dart behaviour would notice until a device
      // did.
      final source = File(
        'lib/features/auth/data/repositories/supabase_auth_repository.dart',
      ).readAsStringSync();
      final initialize = RegExp(
        r'GoogleSignIn\.instance\.initialize\([\s\S]*?\);',
      ).firstMatch(source);
      expect(initialize, isNotNull, reason: 'the init call moved');
      expect(
        initialize!.group(0),
        isNot(contains('nonce')),
        reason: 'a client nonce here can never be satisfied',
      );
      final exchange = RegExp(r'signInWithIdToken\([\s\S]*?\);')
          .firstMatch(source);
      expect(exchange, isNotNull, reason: 'the exchange call moved');
      expect(
        exchange!.group(0),
        isNot(contains('nonce')),
        reason: 'and the exchange must not ask for one either',
      );
    });

    test('a Google account that gives no ID token is not a mystery', () async {
      expect(
        AuthCubit.messageFor('google_sign_in_missing_token'),
        S.authGoogleUnavailable,
      );
    });

    test('the device refusing the account is not read as a dismissal', () {
      // The live failure this guards: Credential Manager wraps
      // `[16] Account reauth failed.` in a `canceled` code, and a dismissal is
      // silent. A refusal must not be.
      expect(
        SupabaseAuthRepository.credentialManagerReason(
          '[16] Account reauth failed.',
        ),
        '16 Account reauth failed',
      );
      expect(
        SupabaseAuthRepository.credentialManagerReason(
          'User canceled activity.',
        ),
        isNull,
        reason: 'that one IS the customer closing the sheet',
      );
      expect(SupabaseAuthRepository.credentialManagerReason(null), isNull);

      expect(
        AuthCubit.messageFor(
          'google_sign_in_refused: 16 Account reauth failed',
        ),
        S.authGoogleRefused,
      );
      expect(S.authGoogleRefused, isNot(S.authFailed));
    });

    test('the Arabic refusal names the Google app and the other door', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      // Written in Arabic script, because an Arabic screen may not carry a
      // Latin run - test/localization_test.dart enforces that, and this
      // assertion used to demand the lettering it forbids.
      expect(S.authGoogleRefused, contains('تطبيق جوجل'));
      expect(S.authGoogleRefused, contains('البريد الإلكتروني'));
    });

    test('a phone with no Google account is told to add one, not to retry', () {
      expect(
        AuthCubit.messageFor('google_no_account_on_device'),
        S.authGoogleNoAccount,
      );
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(S.authGoogleNoAccount, contains('لا يوجد حساب جوجل'));
      expect(S.authGoogleNoAccount, contains('البريد الإلكتروني'));
    });

    test('a misconfigured OAuth client reports the configuration problem', () async {
      // A release build is signed with a different certificate than a debug
      // build, and Google only accepts a certificate whose SHA-1 is registered
      // with the Android OAuth client. When that entry is missing the failure
      // has to say so instead of showing the generic "something went wrong".
      final repo = _FakeAuthRepository()
        ..googleError = const AuthException(
          'google_client_configuration_error',
        );
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthFailure>());
      expect((cubit.state as AuthFailure).message, S.authGoogleUnavailable);
    });

    test('repeated taps while loading do not call repository twice', () async {
      final gate = Completer<void>();
      final repo = _FakeAuthRepository()..googleGate = gate;
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      final first = cubit.signInWithGoogle();
      await cubit.signInWithGoogle();
      expect(repo.googleCalls, 1);

      gate.complete();
      await first;
      expect(cubit.state, isA<AuthSuccess>());
    });

    test('existing email/password authentication still works', () async {
      final repo = _FakeAuthRepository()
        ..signInUser = const AuthUser(id: 'u-1', email: 'u@b.com');
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      await cubit.signIn(email: 'u@b.com', password: 'secret');

      expect(cubit.state, isA<AuthSuccess>());
      expect((cubit.state as AuthSuccess).user.id, 'u-1');
      expect(repo.signInCalls, 1);
    });
  });

  group('Google Sign-In configuration', () {
    test('server client ID is never empty', () {
      expect(AppConfig.googleServerClientId, isNotEmpty);
      expect(
        AppConfig.googleServerClientId,
        '496541472556-j23g42irr9r93rmeuo078513nj6skiu7.apps.googleusercontent.com',
      );
    });
  });

  group('SupabaseAuthRepository Google sign-in', () {
    test('throws AuthException when Supabase is not configured', () async {
      SupabaseService.debugReset();
      addTearDown(SupabaseService.debugReset);

      final repository = SupabaseAuthRepository();

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
