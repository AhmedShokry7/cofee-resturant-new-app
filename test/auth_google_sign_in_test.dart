import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';

class _FakeAuthRepository implements AuthRepository {
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
  }) async =>
      AuthUser(id: email, name: name, email: email);

  @override
  Future<AuthUser> signInWithFacebook() =>
      Future.error(UnimplementedError());

  @override
  Future<AuthUser> signInWithApple() =>
      Future.error(UnimplementedError());

  @override
  Future<void> sendPhoneCode({required String phone}) async {}

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async =>
      AuthUser(id: phone);

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
  }) async =>
      AuthUser(id: 'x', name: fullName, phone: phone);

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
        ..googleError = const AuthException('Google sign-in failed: boom');
      final cubit = AuthCubit(repo);
      addTearDown(cubit.close);

      await cubit.signInWithGoogle();

      expect(cubit.state, isA<AuthFailure>());
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