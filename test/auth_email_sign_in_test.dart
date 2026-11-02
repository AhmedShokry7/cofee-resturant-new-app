import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/email_auth_page_body.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/email_otp_page_body.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

/// The e-mail code door against the provider's answers, not a fake repository.
///
/// Two things are worth proving on the wire: that the address a code was asked
/// for is the address the code is verified against, and that the verify call
/// names the *e-mail* OTP type — a code asked for mail and checked as an SMS
/// code is one error the customer cannot fix.
///
/// The error codes come from this project, measured on 2026-11-02 with the same
/// shape of request the app makes (`otp_disabled`, `email_address_invalid` and
/// `validation_failed` are its answers), plus the codes the provider documents
/// for a stale code and an exhausted mail quota.

const _profileCacheKey = 'cached_profile_v1';
const _uid = '7d000000-0000-4000-8000-000000000004';
const _address = 'ahmed@example.com';

http.Response _json(Object body, int status, http.Request request) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _emailUser({String email = _address}) => {
  'id': _uid,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': email,
  'confirmed_at': '2026-11-02T00:00:00Z',
  'user_metadata': <String, dynamic>{'full_name': 'Ahmed'},
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'identities': [
    {
      'id': _uid,
      'identity_id': _uid,
      'user_id': _uid,
      'provider': 'email',
      'identity_data': {'email': email, 'sub': _uid},
      'created_at': '2026-11-02T00:00:00Z',
      'last_sign_in_at': '2026-11-02T00:00:00Z',
    },
  ],
  'created_at': '2026-11-02T00:00:00Z',
};

Map<String, dynamic> _session({String email = _address}) => {
  'access_token': 'test-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'test-refresh-token',
  'user': _emailUser(email: email),
};

/// The answers of the e-mail endpoints, with every request recorded.
class _Provider {
  _Provider({
    this.otpStatus = 200,
    this.otpError,
    this.verifyStatus = 200,
    this.verifyError,
    this.hasCustomerRow = true,
  });

  final int otpStatus;
  final Map<String, Object>? otpError;
  final int verifyStatus;
  final Map<String, Object>? verifyError;

  /// Whether identity.profiles holds a row for this uid.
  final bool hasCustomerRow;

  final List<String> paths = [];
  final List<String> methods = [];
  final List<Map<String, dynamic>> bodies = [];

  SupabaseClient? _client;

  SupabaseClient client() => _client ??= _build();

  SupabaseClient _build() => SupabaseClient(
    'https://login.test',
    'publishable-test-key',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      paths.add(path);
      methods.add(request.method);
      bodies.add(
        request.body.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(request.body) as Map<String, dynamic>),
      );

      if (path.endsWith('/auth/v1/otp')) {
        if (otpError != null) return _json(otpError!, otpStatus, request);
        return _json({}, 200, request);
      }
      if (path.endsWith('/auth/v1/verify')) {
        if (verifyError != null) {
          return _json(verifyError!, verifyStatus, request);
        }
        return _json(_session(), verifyStatus, request);
      }
      if (path.contains('/rest/v1/profiles')) {
        if (!hasCustomerRow) return _json([], 200, request);
        return _json(
          [
            {'id': _uid},
          ],
          200,
          request,
        );
      }
      return _json({}, 200, request);
    }),
  );

  Map<String, dynamic> bodyFor(String suffix) {
    final index = paths.indexWhere((path) => path.endsWith(suffix));
    return index < 0 ? <String, dynamic>{} : bodies[index];
  }

  bool get asked => paths.any((path) => path.endsWith('/auth/v1/otp'));

  bool get endedSession =>
      paths.any((path) => path.contains('/auth/v1/logout'));
}

/// The screens are tested without a provider: what a screen owns is the shape it
/// hands to the cubit, and a recording repository shows that exactly.
class _RecordingRepository implements AuthRepository {
  final List<String> sentAddresses = [];
  final List<String> verified = [];

  @override
  Future<void> sendEmailCode({required String email}) async {
    sentAddresses.add(email);
  }

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    verified.add('$email|$code');
    return const AuthUser(id: _uid, name: 'Ahmed', email: _address);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Only the e-mail code calls are used here.');
}

Map<String, Object> _error(String code, String msg) => {
  'code': 400,
  'error_code': code,
  'msg': msg,
};

Future<Object?> _throwing(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } catch (error) {
    return error;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(SupabaseService.debugReset);

  group('the address a code is asked for', () {
    test('spaces around it are not sent to the provider', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      await SupabaseAuthRepository().sendEmailCode(email: '  $_address  ');

      expect(provider.bodyFor('/auth/v1/otp')['email'], _address);
    });

    test('an address the provider cannot read never reaches the network', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      for (final typed in ['', 'ahmed', 'ahmed@example']) {
        final thrown = await _throwing(
          () => SupabaseAuthRepository().sendEmailCode(email: typed),
        );

        expect(
          thrown,
          isA<AuthException>(),
          reason: '"$typed" is not an address',
        );
      }
      expect(
        provider.asked,
        isFalse,
        reason:
            'the provider answers a malformed address with the one generic '
            'failure the customer cannot act on, so the shape is checked here',
      );
    });

    test(
      'a mailbox the provider refuses is said in the customer’s words',
      () async {
        // Measured against this project on 2026-11-02: an address on a blocked
        // domain is refused with exactly this code before anything is mailed.
        final provider = _Provider(
          otpStatus: 400,
          otpError: _error(
            'email_address_invalid',
            'Email address "x@example.invalid" is invalid',
          ),
        );
        SupabaseService.debugSetClient(provider.client());

        final thrown = await _throwing(
          () => SupabaseAuthRepository().sendEmailCode(email: _address),
        );

        expect((thrown as AuthException).message, 'email_address_invalid');
      },
    );

    test(
      'a mail door the dashboard holds shut is not a blocked account',
      () async {
        // Also measured on 2026-11-02: `otp_disabled` is this project's answer
        // when no account exists and none may be created. The word `disabled`
        // must not be read as a banned customer.
        final provider = _Provider(
          otpStatus: 422,
          otpError: _error('otp_disabled', 'Signups not allowed for otp'),
        );
        SupabaseService.debugSetClient(provider.client());

        final thrown = await _throwing(
          () => SupabaseAuthRepository().sendEmailCode(email: _address),
        );

        expect((thrown as AuthException).message, 'otp_disabled');
        expect(AuthCubit.messageFor(thrown.message), S.authProviderNotEnabled);
        expect(
          AuthCubit.messageFor(thrown.message),
          isNot(S.authUserDisabled),
          reason: 'the customer is not banned; the door is closed',
        );
      },
    );

    test('an exhausted mail quota is its own answer, not a retry', () async {
      expect(
        AuthCubit.messageFor('over_email_send_rate_limit'),
        S.authTooManyRequests,
      );
    });
  });

  group('the code that trades for a session', () {
    test('is verified as an e-mail code against the same address', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      final user = await SupabaseAuthRepository().verifyEmailCode(
        email: '  $_address  ',
        code: '123456',
      );

      final body = provider.bodyFor('/auth/v1/verify');
      expect(body['email'], _address);
      expect(body['token'], '123456');
      expect(
        body['type'],
        'email',
        reason:
            'a code asked for a mailbox and verified as any other type is '
            'refused by the provider, and the customer sees a wrong-code error',
      );
      expect(user.id, _uid);
      expect(user.email, _address);
    });

    test('leaves a session that outlives this launch', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      await SupabaseAuthRepository().verifyEmailCode(
        email: _address,
        code: '123456',
      );

      final session = SupabaseService.client.auth.currentSession;
      expect(session?.user.id, _uid);
      expect(
        session?.refreshToken,
        isNotEmpty,
        reason:
            'an access token alone is gone in an hour; the refresh token is '
            'what makes the next launch still signed in',
      );
    });

    test('writes the marker the restarted app reads', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());
      final cubit = EmailAuthCubit(SupabaseAuthRepository());

      await cubit.sendCode(email: _address);
      expect(cubit.state, isA<EmailAuthCodeSent>());

      await cubit.verifyCode(email: _address, code: '123456');

      expect(cubit.state, isA<EmailAuthSuccess>());
      expect(
        await const SessionRepository().currentRoute(),
        AppConstant.homeRoute,
        reason:
            'the mail door has to leave the same mark the phone and password '
            'doors do, or the next launch sends this customer to login again',
      );
      await cubit.close();
    });

    test('a stale or replaced code is its own answer', () async {
      final provider = _Provider(
        verifyStatus: 403,
        verifyError: _error('otp_expired', 'Token has expired or is invalid'),
      );
      SupabaseService.debugSetClient(provider.client());

      final thrown = await _throwing(
        () => SupabaseAuthRepository().verifyEmailCode(
          email: _address,
          code: '123456',
        ),
      );

      expect((thrown as AuthException).message, 'otp_expired');
      expect(AuthCubit.messageFor(thrown.message), S.authOtpInvalid);
    });

    test('a staff address is refused, and the session is closed with it', () async {
      // 188_separate_customer_and_staff_accounts.sql makes identity.profiles the
      // customer population. An admin signing into the customer app would order
      // nothing and see nothing, so the door refuses rather than half-opens.
      final provider = _Provider(hasCustomerRow: false);
      SupabaseService.debugSetClient(provider.client());

      final thrown = await _throwing(
        () => SupabaseAuthRepository().verifyEmailCode(
          email: _address,
          code: '123456',
        ),
      );

      expect((thrown as AuthException).message, 'staff account');
      expect(AuthCubit.messageFor(thrown.message), S.authStaffAccount);
      expect(
        provider.endedSession,
        isTrue,
        reason: 'refusing is not enough; the token must not stay on the device',
      );
    });

    test(
      'the profile cache holds the address the customer signed in with',
      () async {
        final provider = _Provider();
        SupabaseService.debugSetClient(provider.client());

        await SupabaseAuthRepository().verifyEmailCode(
          email: _address,
          code: '123456',
        );

        final stored = jsonDecode(
          await SharedPref.getValue(key: _profileCacheKey) as String,
        ) as Map<String, dynamic>;
        expect(stored['email'], _address);
      },
    );
  });

  group('the address screen', () {
    Future<void> pumpAddressScreen(
      WidgetTester tester,
      _RecordingRepository repository, {
      required void Function(Object? arguments) onNavigate,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            onNavigate(settings.arguments);
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            );
          },
          home: Scaffold(
            body: BlocProvider(
              create: (context) => EmailAuthCubit(repository),
              child: const EmailAuthPageBody(),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(CustomBtn));
      await tester.pump();
    }

    testWidgets('hands the cubit and the code screen the same address', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      Object? handover;
      await pumpAddressScreen(
        tester,
        repository,
        onNavigate: (arguments) {
          handover = arguments;
        },
      );

      await tester.enterText(find.byType(TextField), '  $_address ');
      await tester.tap(find.byType(CustomBtn));
      await tester.pumpAndSettle();

      expect(repository.sentAddresses, [_address]);
      expect(
        handover,
        _address,
        reason: 'the code is verified against the address the code was sent to',
      );
    });

    testWidgets(
      'refuses to ask for a code on something that is not an address',
      (tester) async {
        final repository = _RecordingRepository();
        var navigated = false;
        await pumpAddressScreen(
          tester,
          repository,
          onNavigate: (_) => navigated = true,
        );

        await tester.enterText(find.byType(TextField), 'ahmed');
        await tester.tap(find.byType(CustomBtn));
        await tester.pump();

        expect(
          repository.sentAddresses,
          isEmpty,
          reason:
              'the field owns the sentence that says why, before the network',
        );
        expect(
          navigated,
          isFalse,
          reason: 'a rejected address never reaches the code screen',
        );
      },
    );
  });

  group('the code screen', () {
    Future<void> pumpCodeScreen(
      WidgetTester tester,
      _RecordingRepository repository, {
      required void Function(String? route, Object? arguments) onNavigate,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            onNavigate(settings.name, settings.arguments);
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            );
          },
          home: Scaffold(
            body: BlocProvider(
              create: (context) => EmailAuthCubit(repository),
              child: EmailOtpPageBody(email: _address),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(CustomBtn));
      await tester.pump();
    }

    testWidgets('will not trade an incomplete code', (tester) async {
      final repository = _RecordingRepository();
      final routes = <String>[];
      await pumpCodeScreen(
        tester,
        repository,
        onNavigate: (route, _) => routes.add(route ?? ''),
      );

      await tester.enterText(find.byType(TextFormField).first, '12');
      await tester.pump();
      await tester.tap(find.byType(CustomBtn));
      await tester.pumpAndSettle();

      expect(
        find.text(S.enterSixDigitCode),
        findsOneWidget,
        reason: 'the screen says what is missing instead of failing at the provider',
      );
      expect(
        repository.verified,
        isEmpty,
        reason: 'two digits in six boxes never reaches verifyOTP',
      );
      expect(routes, isEmpty);
    });

    testWidgets('a complete code signs in and hands the customer the store', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      final routes = <String>[];
      await pumpCodeScreen(
        tester,
        repository,
        onNavigate: (route, _) => routes.add(route ?? ''),
      );

      await tester.enterText(find.byType(TextFormField).first, '123456');
      await tester.pump();
      await tester.tap(find.byType(CustomBtn));
      await tester.pumpAndSettle();

      expect(
        repository.verified,
        ['$_address|123456'],
        reason:
            'one paste lands in all six boxes and the pair is what is checked',
      );
      expect(routes, [MainPage.routeName]);
    });

    testWidgets('resending asks the same address, not a fresh one', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      await pumpCodeScreen(tester, repository, onNavigate: (_, _) {});

      await tester.tap(find.text(S.resend));
      await tester.pumpAndSettle();

      expect(repository.sentAddresses, [_address]);
    });
  });
}
