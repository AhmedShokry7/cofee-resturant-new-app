import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

/// The parts of the auth layer that only show up against the real provider:
/// what Supabase actually hands back, and what the app then believes.
///
/// Each test here reproduces a defect that a faked repository could not — the
/// unconfirmed sign-up answered "confirmed", the live session answered
/// "authorised to reset", and the signed-out device still held the previous
/// customer's name.

const _profileCacheKey = 'cached_profile_v1';
const _uid = '7d000000-0000-4000-8000-000000000002';
const _email = 'ahmed@gmail.com';

http.Response _json(Object body, int status, http.Request request) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _user({bool confirmed = true}) => {
  'id': _uid,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': _email,
  'email_confirmed_at': confirmed ? '2026-01-01T00:00:00Z' : null,
  'phone': '',
  'user_metadata': {'full_name': 'Ahmed'},
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'identities': [_identities()],
  'created_at': '2026-01-01T00:00:00Z',
};

Map<String, dynamic> _session({bool confirmed = true}) => {
  'access_token': 'test-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'test-refresh-token',
  'user': _user(confirmed: confirmed),
};

Map<String, dynamic> _identities() => {
  'id': _uid,
  'identity_id': _uid,
  'user_id': _uid,
  'provider': 'email',
  'identity_data': {'email': _email, 'full_name': 'Ahmed'},
  'created_at': '2026-01-01T00:00:00Z',
  'last_sign_in_at': '2026-01-01T00:00:00Z',
};

/// Answers the endpoints these flows touch and records every path, so a test
/// can tell the harness "the request that should not happen" from one that did.
SupabaseClient _client({
  required List<String> seen,
  required bool signupReturnsSession,
  required bool hasCustomerRow,
}) {
  return SupabaseClient(
    'https://login.test',
    'publishable-test-key',
    // The app's own client is PKCE, which needs the platform storage to keep a
    // code verifier. Neither the request nor the answer this file cares about
    // changes with the flow, and the fake client has no storage to hand.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      seen.add(path);
      if (path.endsWith('/auth/v1/token')) {
        return _json(_session(), 200, request);
      }
      if (path.endsWith('/auth/v1/signup')) {
        // With confirmation on, the server answers with the user and no
        // session; with it off, it answers with a session.
        return _json(
          signupReturnsSession ? _session() : _user(confirmed: false),
          200,
          request,
        );
      }
      if (path.endsWith('/auth/v1/user')) {
        return _json(_user(), 200, request);
      }
      if (path.endsWith('/auth/v1/logout')) {
        return _json({}, 200, request);
      }
      if (path.contains('/rest/v1/profiles')) {
        return _json(
          hasCustomerRow
              ? [
                  {'id': _uid},
                ]
              : [],
          200,
          request,
        );
      }
      return _json([], 200, request);
    }),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(SupabaseService.debugReset);

  group('a sign-up that still needs confirming', () {
    // gotrue only stores a session when the server handed one over, so
    // `currentUser` is null for exactly the address that needs confirming —
    // which is the case the old check asked about, and always answered "no".
    test('the repository reports the confirmation as pending', () async {
      SupabaseService.debugSetClient(
        _client(seen: [], signupReturnsSession: false, hasCustomerRow: true),
      );
      final repository = SupabaseAuthRepository();

      await repository.signUp(
        name: 'Ahmed',
        email: _email,
        password: 'secret123',
      );

      expect(repository.lastSignUpNeedsEmailConfirmation, isTrue);
    });

    test(
      'no session marker is written, so the next start asks again',
      () async {
        final seen = <String>[];
        SupabaseService.debugSetClient(
          _client(
            seen: seen,
            signupReturnsSession: false,
            hasCustomerRow: true,
          ),
        );
        final cubit = AuthCubit(SupabaseAuthRepository());

        await cubit.signUp(name: 'Ahmed', email: _email, password: 'secret123');

        expect(cubit.state, isA<AuthEmailConfirmationRequired>());
        expect(
          await const SessionRepository().currentRoute(),
          isNot(AppConstant.homeRoute),
          reason:
              'a customer with no session must not be filed under the store',
        );
        final stored = await SharedPref.getValue(key: _profileCacheKey);
        expect(
          stored == null || stored.isEmpty,
          isTrue,
          reason: 'an unconfirmed address has no profile to keep on the device',
        );
        await cubit.close();
      },
    );

    test('a confirmed sign-up still signs the customer in', () async {
      SupabaseService.debugSetClient(
        _client(seen: [], signupReturnsSession: true, hasCustomerRow: true),
      );
      final repository = SupabaseAuthRepository();

      final user = await repository.signUp(
        name: 'Ahmed',
        email: _email,
        password: 'secret123',
      );

      expect(repository.lastSignUpNeedsEmailConfirmation, isFalse);
      expect(user.id, _uid);
      expect(await SharedPref.getValue(key: _profileCacheKey), isNotEmpty);
    });
  });

  group('the password reset screen', () {
    test('refuses a session that was simply already signed in', () async {
      final seen = <String>[];
      SupabaseService.debugSetClient(
        _client(seen: seen, signupReturnsSession: true, hasCustomerRow: true),
      );
      final repository = SupabaseAuthRepository(
        recoverySessionWait: const Duration(milliseconds: 50),
      );
      await repository.signIn(email: _email, password: 'secret123');
      expect(SupabaseService.client.auth.currentSession, isNotNull);

      Object? thrown;
      try {
        await repository.resetPassword(newPassword: 'someoneelseschoice');
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<AuthException>());
      expect((thrown as AuthException).message, 'recovery_link_required');
      expect(
        seen,
        isNot(contains('/auth/v1/user')),
        reason: 'no password may be written on the strength of a live session',
      );
    });

    test('accepts the session the emailed link established', () async {
      final seen = <String>[];
      SupabaseService.debugSetClient(
        _client(seen: seen, signupReturnsSession: true, hasCustomerRow: true),
      );
      final repository = SupabaseAuthRepository(
        recoverySessionWait: const Duration(milliseconds: 50),
      );
      await repository.signIn(email: _email, password: 'secret123');
      SupabaseService.debugSetPasswordRecoverySeen(true);

      await repository.resetPassword(newPassword: 'brandnew123');

      expect(seen, contains('/auth/v1/user'));
    });

    test('the wait-out answer reaches the customer as its own sentence', () {
      expect(
        AuthCubit.messageFor('recovery_link_required'),
        S.authRecoveryLinkRequired,
      );
      expect(
        AuthCubit.messageFor('recovery_link_required'),
        isNot(S.authFailed),
        reason: 'a generic failure tells the customer nothing about the link',
      );
    });
  });

  group('signing out', () {
    test('leaves no profile behind on the device', () async {
      SupabaseService.debugSetClient(
        _client(seen: [], signupReturnsSession: true, hasCustomerRow: true),
      );
      final repository = SupabaseAuthRepository();
      await repository.signIn(email: _email, password: 'secret123');
      expect(await SharedPref.getValue(key: _profileCacheKey), isNotEmpty);

      await repository.signOut();

      final stored = await SharedPref.getValue(key: _profileCacheKey);
      expect(
        stored == null || stored.isEmpty,
        isTrue,
        reason:
            'the next person to hold this phone must not read the '
            "previous customer's name, email or phone out of storage",
      );
    });
  });

  group('the form rules the four auth screens share', () {
    test('an address is checked for shape, not only for emptiness', () {
      expect(AuthFormRules.email(''), S.emailRequired);
      expect(AuthFormRules.email(null), S.emailRequired);
      expect(AuthFormRules.email('ahmed'), S.authInvalidEmail);
      expect(AuthFormRules.email('ahmed@gmail'), S.authInvalidEmail);
      expect(AuthFormRules.email(' ahmed@gmail.com '), isNull);
    });

    test('a chosen password meets the provider floor', () {
      expect(AuthFormRules.newPassword(''), S.passwordRequired);
      expect(AuthFormRules.newPassword('abc'), S.passwordMinLength);
      expect(AuthFormRules.newPassword('abcdef'), isNull);
    });

    test('signing in never rejects a password for being short', () {
      expect(AuthFormRules.password('abc'), isNull);
      expect(AuthFormRules.password(''), S.passwordRequired);
    });

    test('the confirm field compares against what was typed', () {
      expect(AuthFormRules.confirmPassword('abcdef', 'abcdef'), isNull);
      expect(
        AuthFormRules.confirmPassword('abcdeg', 'abcdef'),
        S.passwordsNoMatch,
      );
    });
  });
}
