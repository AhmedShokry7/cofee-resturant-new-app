import 'package:new_coffee/features/auth/data/model/auth_user.dart';

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

  /// Whether the account that was just signed up still has to confirm its
  /// email.
  ///
  /// The sign-up screen asks the repository it was given rather than testing
  /// its class, so a decorator in front of the real repository cannot turn the
  /// question into "no" and send an unconfirmed customer into the app.
  bool get lastSignUpNeedsEmailConfirmation => false;
}
