import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

// 188_separate_customer_and_staff_accounts.sql keeps the two populations in
// their own tables, so a staff login has no identity.profiles row. These tests
// cover what the customer app then does with that fact.

const _staffUid = '7d000000-0000-4000-8000-000000000001';
const _customerUid = '7d000000-0000-4000-8000-000000000002';
const _staffEmail = 'admin@test.local';
const _customerEmail = 'ahmed@gmail.com';

http.Response _json(Object body, int status, http.Request request) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _sessionFor(String uid, String email) => {
  'access_token': 'test-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'test-refresh-token',
  'user': {
    'id': uid,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'email_confirmed_at': '2026-01-01T00:00:00Z',
    'phone': '',
    'user_metadata': {'full_name': 'Test'},
    'app_metadata': {
      'provider': 'email',
      'providers': ['email'],
    },
    'created_at': '2026-01-01T00:00:00Z',
  },
};

/// Answers the three endpoints one password sign-in touches, and records the
/// paths so a test can see whether the session was closed again.
SupabaseClient _client({
  required String uid,
  required String email,
  required bool hasCustomerRow,
  required List<String> seen,
}) {
  return SupabaseClient(
    'https://login.test',
    'publishable-test-key',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      seen.add(path);
      if (path.endsWith('/auth/v1/token')) {
        return _json(_sessionFor(uid, email), 200, request);
      }
      if (path.endsWith('/auth/v1/logout')) {
        return _json({}, 200, request);
      }
      if (path.contains('/rest/v1/profiles')) {
        return _json(
          hasCustomerRow
              ? [
                  {'id': uid},
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

  test('a staff login is refused, and its session is closed', () async {
    final seen = <String>[];
    SupabaseService.debugSetClient(
      _client(
        uid: _staffUid,
        email: _staffEmail,
        hasCustomerRow: false,
        seen: seen,
      ),
    );

    Object? thrown;
    try {
      await SupabaseAuthRepository().signIn(
        email: _staffEmail,
        password: 'anything',
      );
    } catch (error) {
      thrown = error;
    }

    expect(thrown, isA<AuthException>());
    expect((thrown as AuthException).message, 'staff account');
    expect(seen, contains('/auth/v1/token'));
    expect(seen, contains('/rest/v1/profiles'));
    expect(
      seen,
      contains('/auth/v1/logout'),
      reason: 'the session must not stay open',
    );
  });

  test('a customer login still completes', () async {
    final seen = <String>[];
    SupabaseService.debugSetClient(
      _client(
        uid: _customerUid,
        email: _customerEmail,
        hasCustomerRow: true,
        seen: seen,
      ),
    );

    final user = await SupabaseAuthRepository().signIn(
      email: _customerEmail,
      password: 'anything',
    );

    expect(user.id, _customerUid);
    expect(user.email, _customerEmail);
    expect(seen, isNot(contains('/auth/v1/logout')));
  });

  test('the refusal reads as the wrong app, not as wrong credentials', () {
    expect(AuthCubit.messageFor('staff account'), S.authStaffAccount);
    expect(S.authStaffAccount, isNot(S.authInvalidCredentials));
  });

  test('the Arabic sentence names the admin app', () {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(S.authStaffAccount, contains('تطبيق الإدارة'));
  });
}
