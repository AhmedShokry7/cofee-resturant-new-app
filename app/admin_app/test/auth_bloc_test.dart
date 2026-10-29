import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/error/failure.dart';
import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:admin_app/features/auth/domain/usecases/check_session.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_in.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_out.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_state.dart';

const _session = AdminSession(
  staffId: 'u1',
  fullName: 'Manager',
  email: 'manager@example.com',
  status: 'active',
  roles: [],
  permissionScopes: [],
  canManageAllBranches: false,
);

/// مستودع مصطنع يعيد نتيجة محددة ويسجل ما استقبله من البلوك.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.storedSession, this.signInFailure});

  final AdminSession? storedSession;
  final Failure? signInFailure;

  int signInCalls = 0;
  int signOutCalls = 0;
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
    return Success<AdminSession?>(storedSession);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  // البلوك لا يقرأ الدعوات ولا يقبلها، فالعقد هنا مكتفٍ بأن يترك الاختبارات تُكتب.
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

void main() {
  test('starts by checking the stored session', () {
    final bloc = _bloc(_FakeAuthRepository());
    addTearDown(bloc.close);

    expect(bloc.state, const AuthChecking());
  });

  test('a missing stored session leads to the sign-in screen', () async {
    final bloc = _bloc(_FakeAuthRepository());
    addTearDown(bloc.close);

    final expectation = expectLater(bloc.stream, emits(const AuthSignedOut()));
    bloc.add(const AuthSessionCheckRequested());
    await expectation;
  });

  test('a stored session is restored without asking for a password', () async {
    final bloc = _bloc(_FakeAuthRepository(storedSession: _session));
    addTearDown(bloc.close);

    final expectation = expectLater(
      bloc.stream,
      emits(const AuthSignedIn(_session)),
    );
    bloc.add(const AuthSessionCheckRequested());
    await expectation;
  });

  test('a submitted sign-in becomes an active session', () async {
    final repository = _FakeAuthRepository();
    final bloc = _bloc(repository);
    addTearDown(bloc.close);

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder(<Object>[
        const AuthSignedOut(isSubmitting: true),
        const AuthSignedIn(_session),
      ]),
    );
    bloc.add(
      const AuthSignInSubmitted(
        email: 'manager@example.com',
        password: 'secret',
      ),
    );
    await expectation;

    expect(repository.signInCalls, 1);
    expect(repository.lastEmail, 'manager@example.com');
    expect(repository.lastPassword, 'secret');
  });

  test('a failed sign-in returns to the form with its reason', () async {
    final repository = _FakeAuthRepository(
      signInFailure: const InvalidCredentialsFailure(),
    );
    final bloc = _bloc(repository);
    addTearDown(bloc.close);

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder(<Object>[
        const AuthSignedOut(isSubmitting: true),
        const AuthSignedOut(failure: InvalidCredentialsFailure()),
      ]),
    );
    bloc.add(
      const AuthSignInSubmitted(email: 'manager@example.com', password: 'x'),
    );
    await expectation;
  });

  test('the visibility toggle flips the password field state', () async {
    final bloc = _bloc(_FakeAuthRepository());
    addTearDown(bloc.close);

    final signedOut = expectLater(bloc.stream, emits(isA<AuthSignedOut>()));
    bloc.add(const AuthSessionCheckRequested());
    await signedOut;

    final toggled = expectLater(
      bloc.stream,
      emits(const AuthSignedOut(obscurePassword: false)),
    );
    bloc.add(const AuthPasswordVisibilityToggled());
    await toggled;
  });

  test('signing out clears the session even before it is restored', () async {
    final repository = _FakeAuthRepository(storedSession: _session);
    final bloc = _bloc(repository);
    addTearDown(bloc.close);

    final expectation = expectLater(bloc.stream, emits(const AuthSignedOut()));
    bloc.add(const AuthSignOutRequested());
    await expectation;

    expect(repository.signOutCalls, 1);
  });
}
