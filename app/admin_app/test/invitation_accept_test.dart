import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:admin_app/features/auth/presentation/manager/invitation_accept_cubit.dart';
import 'package:admin_app/features/auth/presentation/manager/invitation_accept_state.dart';
import 'package:admin_app/features/auth/presentation/widgets/invitation_accept_dialog.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_password_field.dart';

import 'helpers/stub_supabase_client.dart';

const _token = '3f6a2b1e-8c4d-4e5f-9a0b-1c2d3e4f5a6b';
const _invitedEmail = 'chef@example.com';

/// مستودع مصادقة يجيب بما يريده الاختبار ويسجّل ما طُلب منه.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.lookup, this.acceptOutcome});

  InvitationLookup? lookup;
  InvitationAcceptOutcome? acceptOutcome;

  final List<String> lookedUp = <String>[];
  final List<Map<String, String>> accepted = <Map<String, String>>[];

  @override
  Future<Result<AdminSession>> signIn({
    required String email,
    required String password,
  }) async => const Success<AdminSession>(_session);

  @override
  Future<Result<AdminSession?>> restoreSession() async =>
      const Success<AdminSession?>(null);

  @override
  Future<void> signOut() async {}

  @override
  Future<InvitationLookup> lookupInvitation(String token) async {
    lookedUp.add(token);
    return lookup ??
        const InvitationLookup.refused(InvitationAcceptOutcome.unknown);
  }

  @override
  Future<InvitationAcceptOutcome> acceptInvitation({
    required String token,
    required String email,
    required String password,
  }) async {
    accepted.add({'token': token, 'email': email, 'password': password});
    return acceptOutcome ?? InvitationAcceptOutcome.accepted;
  }
}

const _session = AdminSession(
  staffId: 'u1',
  fullName: 'Chef One',
  email: _invitedEmail,
  status: 'active',
  roles: [],
  permissionScopes: [],
  canManageAllBranches: false,
);

const _preview = InvitationPreview(
  email: _invitedEmail,
  fullName: 'Chef One',
  roleName: 'Manager',
  branchName: 'Main',
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('the cubit', () {
    test('a live code becomes the preview the database named', () async {
      final repository = _FakeAuthRepository(
        lookup: const InvitationLookup.found(_preview),
      );
      final cubit = InvitationAcceptCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.check(_token);

      expect(cubit.state.status, InvitationAcceptStatus.preview);
      expect(cubit.state.preview, _preview);
    });

    test(
      'a dead code is a refusal with the reason the database gave',
      () async {
        final repository = _FakeAuthRepository(
          lookup: const InvitationLookup.refused(
            InvitationAcceptOutcome.expired,
          ),
        );
        final cubit = InvitationAcceptCubit(repository: repository);
        addTearDown(cubit.close);

        await cubit.check(_token);

        expect(cubit.state.status, InvitationAcceptStatus.refused);
        expect(cubit.state.outcome, InvitationAcceptOutcome.expired);
        expect(cubit.state.preview, isNull);
      },
    );

    test('nothing is accepted before a code is read', () async {
      final repository = _FakeAuthRepository();
      final cubit = InvitationAcceptCubit(repository: repository);
      addTearDown(cubit.close);

      expect(await cubit.accept(token: _token, password: 'secret123'), isNull);
      expect(repository.accepted, isEmpty);
    });

    test(
      'an accepted invitation answers with the email of the invitation',
      () async {
        final repository = _FakeAuthRepository(
          lookup: const InvitationLookup.found(_preview),
        );
        final cubit = InvitationAcceptCubit(repository: repository);
        addTearDown(cubit.close);

        await cubit.check(_token);
        final email = await cubit.accept(token: _token, password: 'secret123');

        // بريد الدعوة لا ما كتبته الشاشة: به تُفتح الجلسة التالية.
        expect(email, _invitedEmail);
        expect(repository.accepted.single, {
          'token': _token,
          'email': _invitedEmail,
          'password': 'secret123',
        });
        expect(cubit.state.status, InvitationAcceptStatus.accepted);
      },
    );

    test(
      'a refusal after the password keeps the reason and gives no email',
      () async {
        final repository = _FakeAuthRepository(
          lookup: const InvitationLookup.found(_preview),
          acceptOutcome: InvitationAcceptOutcome.customerHistory,
        );
        final cubit = InvitationAcceptCubit(repository: repository);
        addTearDown(cubit.close);

        await cubit.check(_token);

        expect(
          await cubit.accept(token: _token, password: 'secret123'),
          isNull,
        );
        expect(cubit.state.status, InvitationAcceptStatus.refused);
        expect(cubit.state.outcome, InvitationAcceptOutcome.customerHistory);
      },
    );

    test('a fault in the read is a refusal, never a silent blank', () async {
      final cubit = InvitationAcceptCubit(repository: _ThrowingRepository());
      addTearDown(cubit.close);

      await cubit.check(_token);

      expect(cubit.state.status, InvitationAcceptStatus.refused);
      expect(cubit.state.outcome, InvitationAcceptOutcome.failed);
    });
  });

  group('the repository', () {
    test('a code that is not a uuid never reaches the database', () async {
      final client = StubSupabaseFunctions();

      final answer = await SupabaseAuthRepository(client)
          .lookupInvitation('  not-a-code  ');

      expect(answer.isFound, isFalse);
      expect(answer.outcome, InvitationAcceptOutcome.unknown);
      expect(client.events, isEmpty);
    });

    test('a live answer carries who, which role and which branch', () async {
      final client = StubSupabaseFunctions(
        responses: <String, Object?>{
          'admin_invitation_lookup': <String, dynamic>{
            'ok': true,
            'email': _invitedEmail,
            'full_name': 'Chef One',
            'role_code': 'manager',
            'role_name_ar': 'مدير',
            'role_name_en': 'Manager',
            'branch_name_ar': 'الرئيسي',
            'branch_name_en': 'Main',
          },
        },
      );

      final answer = await SupabaseAuthRepository(client)
          .lookupInvitation(_token);

      expect(client.params['admin_invitation_lookup'], <String, dynamic>{
        'p_token': _token,
      });
      expect(answer.preview?.fullName, 'Chef One');
      expect(answer.preview?.email, _invitedEmail);
      expect(answer.preview?.roleName, 'Manager');
      expect(answer.preview?.branchName, 'Main');
    });

    test(
      'a role the answer only codes is shown by its code, not invented',
      () async {
        final answer = await SupabaseAuthRepository(
          StubSupabaseFunctions(
            responses: <String, Object?>{
              'admin_invitation_lookup': <String, dynamic>{
                'ok': true,
                'email': _invitedEmail,
                'full_name': 'Chef One',
                'role_code': 'floor_lead',
              },
            },
          ),
        ).lookupInvitation(_token);

        expect(answer.preview?.roleName, 'floor_lead');
        // لا فرع ولا اسم فرع: الدعوة على مستوى المنصة، وتُعرض بلا فرع.
        expect(answer.preview?.branchName, isNull);
      },
    );

    test('every dead-code reason becomes its own outcome', () async {
      const reasons = <String, InvitationAcceptOutcome>{
        'unknown': InvitationAcceptOutcome.unknown,
        'accepted': InvitationAcceptOutcome.alreadyAccepted,
        'cancelled': InvitationAcceptOutcome.cancelled,
        'expired': InvitationAcceptOutcome.expired,
        'anything else': InvitationAcceptOutcome.failed,
      };
      for (final entry in reasons.entries) {
        final answer = await SupabaseAuthRepository(
          StubSupabaseFunctions(
            responses: <String, Object?>{
              'admin_invitation_lookup': <String, dynamic>{
                'ok': false,
                'reason': entry.key,
              },
            },
          ),
        ).lookupInvitation(_token);
        expect(answer.outcome, entry.value, reason: entry.key);
        expect(answer.isFound, isFalse, reason: entry.key);
      }
    });

    test('a wall on the read is a failure the screen can name', () async {
      final answer = await SupabaseAuthRepository(
        StubSupabaseFunctions(
          errors: <String, Object>{
            'admin_invitation_lookup': PostgrestException(
              message: 'permission denied',
              code: '42501',
            ),
          },
        ),
      ).lookupInvitation(_token);

      expect(answer.outcome, InvitationAcceptOutcome.failed);
    });

    test('a code that is not a uuid never opens an account', () async {
      final client = StubSupabaseFunctions();

      final outcome = await SupabaseAuthRepository(
        client,
      ).acceptInvitation(token: 'short', email: _invitedEmail, password: 'x');

      expect(outcome, InvitationAcceptOutcome.unknown);
      // `client.auth` لم يُمسّ: لا حساب بلا دعوة ولا جلسة معلّقة.
      expect(client.events, isEmpty);
    });
  });

  group('the dialog', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showInvitationAcceptDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('the code field asks for the code and nothing else first', (
      tester,
    ) async {
      await open(tester);

      expect(find.text(S.invitationAcceptTitle), findsOneWidget);
      expect(find.text(S.invitationCodeLabel), findsOneWidget);
      // لا حقل كلمة مرور قبل أن تُقرأ الدعوة: لا يُكتب سرّ في فراغ.
      expect(find.byType(LoginPasswordField), findsNothing);
    });

    testWidgets('an empty code is answered locally, not by the network', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text(S.invitationCheck));
      await tester.pumpAndSettle();

      expect(find.text(S.invitationCodeRequired), findsOneWidget);
      expect(find.text(S.invitationUnknown), findsNothing);
    });

    testWidgets('a code that is not a format the database issues is refused', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, S.invitationCodeHint),
        'chef-invite',
      );
      await tester.tap(find.text(S.invitationCheck));
      await tester.pumpAndSettle();

      // الحارس محلي في المستودع، فلا رحلة شبكة تسأل عن رمز يعرف شكله أنه خطأ.
      expect(find.text(S.invitationUnknown), findsOneWidget);
      expect(find.byType(LoginPasswordField), findsNothing);
    });
  });
}

class _ThrowingRepository implements AuthRepository {
  @override
  Future<Result<AdminSession>> signIn({
    required String email,
    required String password,
  }) async => const Success<AdminSession>(_session);

  @override
  Future<Result<AdminSession?>> restoreSession() async =>
      const Success<AdminSession?>(null);

  @override
  Future<void> signOut() async {}

  @override
  Future<InvitationLookup> lookupInvitation(String token) async =>
      throw Exception('offline');

  @override
  Future<InvitationAcceptOutcome> acceptInvitation({
    required String token,
    required String email,
    required String password,
  }) async => InvitationAcceptOutcome.failed;
}
