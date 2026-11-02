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
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/phone_auth_page_body.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

/// Phone sign-in against the provider's answers rather than a fake repository.
///
/// The number is the credential, so the two things worth proving are the shape
/// the number reaches the server in — a code requested for `+966501234567` must
/// be verified against that same string — and what each of the provider's phone
/// errors becomes on an Arabic screen. A scripted repository can answer
/// "it threw"; only the wire shows which code it threw.
///
/// The error codes are the ones this project answers with today
/// (`phone_provider_disabled`, `otp_disabled`, `otp_expired` were measured
/// against it on 2026-11-02) and the ones the provider documents for SMS.

const _profileCacheKey = 'cached_profile_v1';
const _uid = '7d000000-0000-4000-8000-000000000003';
const _e164 = '+966501234567';

http.Response _json(Object body, int status, http.Request request) =>
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _phoneUser({String phone = _e164}) => {
  'id': _uid,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': '',
  'phone': phone,
  'confirmed_at': '2026-11-02T00:00:00Z',
  'user_metadata': <String, dynamic>{},
  'app_metadata': {
    'provider': 'phone',
    'providers': ['phone'],
  },
  'identities': [
    {
      'id': _uid,
      'identity_id': _uid,
      'user_id': _uid,
      'provider': 'phone',
      'identity_data': {'phone': phone, 'sub': _uid},
      'created_at': '2026-11-02T00:00:00Z',
      'last_sign_in_at': '2026-11-02T00:00:00Z',
    },
  ],
  'created_at': '2026-11-02T00:00:00Z',
};

Map<String, dynamic> _session() => {
  'access_token': 'test-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at':
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000,
  'refresh_token': 'test-refresh-token',
  'user': _phoneUser(),
};

/// The answers of the phone endpoints, with every request recorded.
class _Provider {
  _Provider({
    this.otpStatus = 200,
    this.otpError,
    this.verifyStatus = 200,
    this.verifyError,
    this.hasCustomerRow = true,
    this.phoneInProfile,
  });

  final int otpStatus;
  final Map<String, Object>? otpError;
  final int verifyStatus;
  final Map<String, Object>? verifyError;

  /// Whether identity.profiles holds a row for this uid.
  final bool hasCustomerRow;

  /// The number already stored on the row, or null when the column is empty —
  /// which is the state every phone account is in, because the signup trigger
  /// only ever copies an email.
  final String? phoneInProfile;

  final List<String> paths = [];
  final List<String> methods = [];
  final List<Map<String, dynamic>> bodies = [];

  SupabaseClient? _client;

  /// The fake provider, built once so the requests it answers land in the
  /// lists this test reads back.
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
            {'id': _uid, 'phone': phoneInProfile},
          ],
          200,
          request,
        );
      }
      return _json({}, 200, request);
    }),
  );

  /// The decoded body of the first call to one endpoint.
  Map<String, dynamic> bodyFor(String suffix) {
    final index = paths.indexWhere((path) => path.endsWith(suffix));
    return index < 0 ? <String, dynamic>{} : bodies[index];
  }

  bool get asked => paths.any((path) => path.endsWith('/auth/v1/otp'));

  bool get patchedProfile => paths.asMap().entries.any(
    (entry) =>
        entry.value.contains('/rest/v1/profiles') &&
        methods[entry.key] == 'PATCH',
  );
}

/// The screens are tested without a provider: what a screen owns is the shape it
/// hands to the cubit, and a recording repository shows that exactly.
class _RecordingRepository implements AuthRepository {
  final List<String> sentPhones = [];

  @override
  Future<void> sendPhoneCode({required String phone}) async {
    sentPhones.add(phone);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Only sendPhoneCode is used on this screen.');
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

  group('the number a code is requested for', () {
    test('a local number is completed before the provider is asked', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      await SupabaseAuthRepository().sendPhoneCode(phone: '050 123 4567');

      expect(provider.bodyFor('/auth/v1/otp')['phone'], _e164);
    });

    test('the same number written three ways is one number', () async {
      for (final typed in ['+966501234567', '00966501234567', '0501234567']) {
        final provider = _Provider();
        SupabaseService.debugSetClient(provider.client());

        await SupabaseAuthRepository().sendPhoneCode(phone: typed);

        expect(
          provider.bodyFor('/auth/v1/otp')['phone'],
          _e164,
          reason: '"$typed" is the same number read out different ways',
        );
        SupabaseService.debugReset();
      }
    });

    test('a foreign number is not given this country', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      await SupabaseAuthRepository().sendPhoneCode(phone: '41793026727');

      expect(
        provider.bodyFor('/auth/v1/otp')['phone'],
        '+41793026727',
        reason: 'ten digits without a + is not proof they are Saudi',
      );
    });

    test('a number too short to route never reaches the network', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      final thrown = await _throwing(
        () => SupabaseAuthRepository().sendPhoneCode(phone: '1234'),
      );

      expect(thrown, isA<AuthException>());
      expect(provider.asked, isFalse);
    });

    test('a phone door that is not open says so, and is not a blocked account', () async {
      // Measured against this project on 2026-11-02: with the provider off it
      // answers exactly this. The two sentences differ by whether the customer
      // can ever sign in with a number at all.
      final provider = _Provider(
        otpStatus: 400,
        otpError: _error(
          'phone_provider_disabled',
          'Unsupported phone provider',
        ),
      );
      SupabaseService.debugSetClient(provider.client());

      final thrown = await _throwing(
        () => SupabaseAuthRepository().sendPhoneCode(phone: _e164),
      );

      expect((thrown as AuthException).message, 'phone_provider_disabled');
      expect(AuthCubit.messageFor(thrown.message), S.authProviderNotEnabled);
      expect(
        AuthCubit.messageFor(thrown.message),
        isNot(S.authUserDisabled),
        reason: 'the code ends in "disabled", which is not what it means',
      );
    });

    test(
      'an exhausted message quota is not sold as a blocked account',
      () async {
        final provider = _Provider(
          otpStatus: 429,
          otpError: _error('over_sms_send_rate_limit', 'Too many SMS sent'),
        );
        SupabaseService.debugSetClient(provider.client());

        final thrown = await _throwing(
          () => SupabaseAuthRepository().sendPhoneCode(phone: _e164),
        );

        expect((thrown as AuthException).message, 'over_sms_send_rate_limit');
        expect(AuthCubit.messageFor(thrown.message), S.authTooManyRequests);
      },
    );

    test(
      'a message the provider could not send names the other door',
      () async {
        expect(AuthCubit.messageFor('sms_send_failed'), S.authSmsSendFailed);
        expect(
          AuthCubit.messageFor('sms_send_failed'),
          isNot(S.authFailed),
          reason: 'the number is fine; it is the message that did not leave',
        );
      },
    );
  });

  group('the code that trades for a session', () {
    test('is verified against the same number that was sent', () async {
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      final user = await SupabaseAuthRepository().verifyPhoneCode(
        phone: '050 123 4567',
        code: '123456',
      );

      final body = provider.bodyFor('/auth/v1/verify');
      expect(body['phone'], _e164);
      expect(body['token'], '123456');
      expect(body['type'], 'sms');
      expect(user.id, _uid);
    });

    test(
      'leaves a session on the device that can outlive this launch',
      () async {
        final provider = _Provider();
        SupabaseService.debugSetClient(provider.client());

        await SupabaseAuthRepository().verifyPhoneCode(
          phone: _e164,
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
      },
    );

    test(
      'the next start is filed under the store, not the login screen',
      () async {
        final provider = _Provider();
        SupabaseService.debugSetClient(provider.client());
        final cubit = PhoneAuthCubit(SupabaseAuthRepository());

        await cubit.verifyCode(phone: _e164, code: '123456');

        expect(cubit.state, isA<PhoneAuthSuccess>());
        expect(
          await const SessionRepository().currentRoute(),
          AppConstant.homeRoute,
          reason:
              'the marker is what the restarted app reads, so it must be '
              'written by the phone path exactly as the email path writes it',
        );
        await cubit.close();
      },
    );

    test('the proved number is stored where the app reads a phone', () async {
      // identity.handle_new_user() copies an email and knows nothing about a
      // phone, so without this a customer who signed in by SMS has a session and
      // no number anywhere.
      final provider = _Provider();
      SupabaseService.debugSetClient(provider.client());

      await SupabaseAuthRepository().verifyPhoneCode(
        phone: _e164,
        code: '123456',
      );

      expect(provider.patchedProfile, isTrue);
      final stored = jsonDecode(
        await SharedPref.getValue(key: _profileCacheKey) as String,
      ) as Map<String, dynamic>;
      expect(stored['phone'], _e164);
    });

    test('a number the customer already stored is not overwritten', () async {
      final provider = _Provider(phoneInProfile: '+966500000000');
      SupabaseService.debugSetClient(provider.client());

      await SupabaseAuthRepository().verifyPhoneCode(
        phone: _e164,
        code: '123456',
      );

      expect(
        provider.patchedProfile,
        isFalse,
        reason: 'what the customer typed on their profile outranks this',
      );
    });

    test('an expired or replaced code is its own answer', () async {
      final provider = _Provider(
        verifyStatus: 403,
        verifyError: _error('otp_expired', 'Token has expired or is invalid'),
      );
      SupabaseService.debugSetClient(provider.client());

      final thrown = await _throwing(
        () => SupabaseAuthRepository().verifyPhoneCode(
          phone: _e164,
          code: '111111',
        ),
      );

      expect((thrown as AuthException).message, 'otp_expired');
      expect(AuthCubit.messageFor(thrown.message), S.authOtpInvalid);
    });

    test(
      'a number that belongs to staff is refused and the session dropped',
      () async {
        final provider = _Provider(hasCustomerRow: false);
        SupabaseService.debugSetClient(provider.client());

        final thrown = await _throwing(
          () => SupabaseAuthRepository().verifyPhoneCode(
            phone: _e164,
            code: '123456',
          ),
        );

        expect((thrown as AuthException).message, 'staff account');
        expect(
          provider.paths,
          contains('/auth/v1/logout'),
          reason: 'a session with no customer row must not stay on the device',
        );
      },
    );
  });

  group('the field the customer types into', () {
    test('asks for a number a message can be sent to', () {
      expect(AuthFormRules.phone(''), S.phoneRequired);
      expect(AuthFormRules.phone('   '), S.phoneRequired);
      expect(AuthFormRules.phone('0501234567'), isNull);
      expect(AuthFormRules.phone(_e164), isNull);
      expect(AuthFormRules.phone('12345'), S.validPhoneNumber);
      expect(AuthFormRules.phone('not a number'), S.validPhoneNumber);
    });

    test('is the same rule the repository sends with', () {
      // The screen and the call must not own two copies of a phone shape, or a
      // code is requested for one number and verified against another.
      expect(AuthFormRules.e164Of('050 123 4567'), _e164);
      expect(AuthFormRules.e164Of('501234567'), _e164);
      expect(AuthFormRules.e164Of('00966 50 123 4567'), _e164);
      expect(AuthFormRules.e164Of('+966-50-123-4567'), _e164);
      expect(AuthFormRules.e164Of('+1 202 555 0100'), '+12025550100');
      expect(AuthFormRules.e164Of('12345'), isNull);
      expect(AuthFormRules.e164Of(''), isNull);
      expect(AuthFormRules.e164Of(null), isNull);
      expect(AuthFormRules.e164Of('+1'), isNull);
      expect(AuthFormRules.e164Of('+9665012345678901234'), isNull);
    });
  });

  group('the phone screen', () {
    Future<void> pumpPhoneScreen(
      WidgetTester tester,
      _RecordingRepository repository, {
      required void Function(Object? arguments) onNavigate,
    }) async {
      tester.view.physicalSize = const Size(360, 800);
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
              create: (context) => PhoneAuthCubit(repository),
              child: const PhoneAuthPageBody(),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byType(CustomBtn));
      await tester.pump();
    }

    testWidgets('sends the completed number and hands the same one over', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      Object? handover;
      await pumpPhoneScreen(
        tester,
        repository,
        onNavigate: (arguments) {
          handover = arguments;
        },
      );

      await tester.enterText(find.byType(TextFormField).first, '050 123 4567');
      await tester.pump();
      await tester.tap(find.text(S.sendCode));
      await tester.pumpAndSettle();

      expect(repository.sentPhones, [
        _e164,
      ], reason: 'the screen asks for the number the provider will read');
      expect(
        handover,
        _e164,
        reason: 'the OTP screen verifies against the number that was sent to',
      );
    });

    testWidgets('refuses an unsendable number before asking the provider', (
      tester,
    ) async {
      final repository = _RecordingRepository();
      await pumpPhoneScreen(tester, repository, onNavigate: (_) {});

      await tester.enterText(find.byType(TextFormField).first, '1234');
      await tester.pump();
      await tester.tap(find.text(S.sendCode));
      await tester.pumpAndSettle();

      expect(repository.sentPhones, isEmpty);
      expect(find.text(S.validPhoneNumber), findsOneWidget);
    });
  });
}
