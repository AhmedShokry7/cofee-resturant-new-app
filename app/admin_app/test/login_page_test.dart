import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/error/failure.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:admin_app/features/auth/domain/usecases/check_session.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_in.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_out.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/pages/login_page.dart';

const _session = AdminSession(
  staffId: 'u1',
  fullName: 'Manager',
  email: 'manager@example.com',
  status: 'active',
  roles: [],
  permissionScopes: [],
  canManageAllBranches: false,
);

/// مستودع مصطنع يعيد نتيجة محددة ويسجل بيانات الدخول التي وصلته.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInFailure});

  final Failure? signInFailure;

  int signInCalls = 0;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<Result<AdminSession>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    lastEmail = email;
    lastPassword = password;

    final failure = signInFailure;
    if (failure != null) return ResultFailure<AdminSession>(failure);
    return const Success<AdminSession>(_session);
  }

  @override
  Future<Result<AdminSession?>> restoreSession() async {
    return const Success<AdminSession?>(null);
  }

  @override
  Future<void> signOut() async {}

  // شاشة الدخول لا تمرّ بالدعوة في هذه الاختبارات، فيكفي عقد يرفض رمزًا غير معروف.
  @override
  Future<InvitationLookup> lookupInvitation(String token) async =>
      InvitationLookup.refused(InvitationAcceptOutcome.unknown);

  @override
  Future<InvitationAcceptOutcome> acceptInvitation({
    required String token,
    required String email,
    required String password,
  }) async => InvitationAcceptOutcome.unknown;
}

AuthBloc _bloc(_FakeAuthRepository repository) => AuthBloc(
  checkSessionUseCase: CheckSessionUseCase(repository),
  signInUseCase: SignInUseCase(repository),
  signOutUseCase: SignOutUseCase(repository),
);

Future<AuthBloc> _pumpLogin(
  WidgetTester tester,
  _FakeAuthRepository repository,
) async {
  final bloc = _bloc(repository);
  addTearDown(bloc.close);

  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp(home: const LoginPage()),
    ),
  );
  await tester.pump();

  // شاشة الدخول تظهر بعد انتهاء فحص الجلسة، وهو ما يفعله AuthGate في التطبيق.
  bloc.add(const AuthSessionCheckRequested());
  await tester.pump();
  return bloc;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the sign-in page shows the form and its labels', (tester) async {
    await _pumpLogin(tester, _FakeAuthRepository());

    expect(find.text(S.staffSignIn), findsOneWidget);
    expect(find.text(S.staffSignInSubtitle), findsOneWidget);
    expect(find.text(S.email), findsOneWidget);
    expect(find.text(S.password), findsOneWidget);
    expect(find.text(S.signIn), findsOneWidget);
  });

  testWidgets('submitting the form sends the typed credentials', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpLogin(tester, repository);

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text(S.signIn));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 1);
    expect(repository.lastEmail, 'manager@example.com');
    expect(repository.lastPassword, 'secret');
  });

  testWidgets('an invalid email stops the form before the network call', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpLogin(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text(S.signIn));
    await tester.pump();

    expect(repository.signInCalls, 0);
    expect(find.text(S.validEmail), findsOneWidget);
  });

  testWidgets('the password toggle changes the field visibility', (
    tester,
  ) async {
    await _pumpLogin(tester, _FakeAuthRepository());

    expect(find.byTooltip(S.showPassword), findsOneWidget);
    await tester.tap(find.byTooltip(S.showPassword));
    await tester.pump();

    expect(find.byTooltip(S.hidePassword), findsOneWidget);
  });

  testWidgets('a rejected sign-in shows the reason above the form', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      _FakeAuthRepository(signInFailure: const InvalidCredentialsFailure()),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'manager@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.text(S.signIn));
    await tester.pumpAndSettle();

    expect(find.text(S.invalidCredentials), findsOneWidget);
  });

  testWidgets(
    'the invitation entry opens the code dialog on the sign-in screen',
    (tester) async {
      final repository = _FakeAuthRepository();
      await _pumpLogin(tester, repository);

      await tester.tap(find.text(S.invitationEntry));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text(S.invitationAcceptTitle), findsOneWidget);
      expect(find.text(S.invitationCodeLabel), findsOneWidget);
      // لا محاولة دخول جرت: الحوار يقرأ الرمز أولًا ولا يفترض شيئًا.
      expect(repository.signInCalls, 0);
    },
  );
}
