import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/password_reset/password_reset_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A customer who leaves the screen before the network answers.
///
/// Popping the page closes its cubit, and `bloc` refuses to emit into a closed
/// one. Every unguarded `emit` after an `await` therefore turned the answer the
/// request was about to report into a `StateError` thrown into the zone — a
/// crash the customer never sees, and no error message either.
///
/// [AuthRepository] hangs on purpose: each test closes the cubit while the call
/// is still out, then lets it return, and requires that nothing is thrown.
class _HangingRepository implements AuthRepository {
  _HangingRepository({this.failure});

  /// What the call throws once released. `null` means it succeeds.
  final Object? failure;

  final Completer<void> _release = Completer<void>();

  Future<void> _wait() async {
    await _release.future;
    final error = failure;
    if (error != null) throw error;
  }

  static const AuthUser _ahmed = AuthUser(
    id: 'u1',
    name: 'Ahmed',
    email: 'ahmed@gmail.com',
  );

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _wait().then((_) => _ahmed);

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) => _wait().then((_) => _ahmed);

  @override
  Future<AuthUser> signInWithGoogle() async {
    await _release.future;
    // The sheet was dismissed while the screen was gone.
    throw const AuthException('google_sign_in_canceled');
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) => _wait();

  @override
  Future<void> resetPassword({required String newPassword}) => _wait();

  @override
  Future<void> sendPhoneCode({required String phone}) => _wait();

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) => _wait().then((_) => _ahmed);

  @override
  Future<void> sendEmailCode({required String email}) => _wait();

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) => _wait().then((_) => _ahmed);

  @override
  Future<void> signOut() => _wait();

  @override
  Future<AuthUser?> currentUser() async => _ahmed;

  @override
  bool get lastSignUpNeedsEmailConfirmation => false;

  @override
  Future<AuthUser> signInWithFacebook() async =>
      throw UnsupportedError('not part of this test');

  @override
  Future<AuthUser> signInWithApple() async =>
      throw UnsupportedError('not part of this test');

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async => throw UnsupportedError('not part of this test');

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async => throw UnsupportedError('not part of this test');
}

/// Closes [cubit] mid-request, then lets the provider answer.
Future<void> _answeredAfterTheScreenWasGone(
  _HangingRepository repository,
  Cubit<Object?> cubit,
  Future<void> pending,
) async {
  await cubit.close();
  repository._release.complete();
  await pending;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('the request answers after its screen is closed', () {
    test('a sign-in', () {
      final repository = _HangingRepository();
      final cubit = AuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.signIn(email: 'ahmed@gmail.com', password: 'secret123'),
      );
    });

    test('a sign-in the provider refused', () {
      final repository = _HangingRepository(
        failure: const AuthException('invalid_credentials'),
      );
      final cubit = AuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.signIn(email: 'ahmed@gmail.com', password: 'wrong'),
      );
    });

    test('a sign-in that failed in a way nobody predicted', () {
      final repository = _HangingRepository(failure: StateError('socket died'));
      final cubit = AuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.signUp(
          name: 'Ahmed',
          email: 'ahmed@gmail.com',
          password: 'secret123',
        ),
      );
    });

    test('a Google sheet the customer dismissed', () {
      final repository = _HangingRepository();
      final cubit = AuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.signInWithGoogle(),
      );
    });

    test('a sign-out', () {
      final repository = _HangingRepository();
      final cubit = AuthCubit(repository);
      return _answeredAfterTheScreenWasGone(repository, cubit, cubit.signOut());
    });

    test('a reset email', () {
      final repository = _HangingRepository();
      final cubit = PasswordResetCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.sendEmail(email: 'ahmed@gmail.com'),
      );
    });

    test('a refused reset email', () {
      final repository = _HangingRepository(
        failure: const AuthException('over_request_rate_limit'),
      );
      final cubit = PasswordResetCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.sendEmail(email: 'ahmed@gmail.com'),
      );
    });

    test('a new password', () {
      final repository = _HangingRepository();
      final cubit = PasswordResetCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.resetPassword(password: 'secret123'),
      );
    });

    test('a phone code', () {
      final repository = _HangingRepository();
      final cubit = PhoneAuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.sendCode(phone: '+20123456789'),
      );
    });

    test('a refused phone code', () {
      final repository = _HangingRepository(
        failure: const AuthException('invalid_credentials'),
      );
      final cubit = PhoneAuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.verifyCode(phone: '+20123456789', code: '123456'),
      );
    });

    test('a verified phone code', () {
      final repository = _HangingRepository();
      final cubit = PhoneAuthCubit(repository);
      return _answeredAfterTheScreenWasGone(
        repository,
        cubit,
        cubit.verifyCode(phone: '+20123456789', code: '123456'),
      );
    });
  });
}
