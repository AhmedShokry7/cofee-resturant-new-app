import 'package:new_coffee/features/auth/data/models/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser> signIn({
    required String email,
    required String password,
  });

  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithFacebook();

  Future<AuthUser> signInWithApple();

  Future<void> sendPhoneCode({required String phone});

  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> resetPassword({required String newPassword});

  Future<void> signOut();

  Future<AuthUser?> currentUser();

  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  });

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}
