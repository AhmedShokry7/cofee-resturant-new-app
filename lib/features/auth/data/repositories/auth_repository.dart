import 'package:new_coffee/features/auth/data/model/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser> signIn({required String email, required String password});

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

  /// Asks the provider to put a sign-in code in the customer's mailbox.
  ///
  /// The mailbox is a door of its own, next to the phone number and Google: a
  /// customer who has neither a reachable number nor a Google account on the
  /// device still has an address. The message itself is sent by the server,
  /// never by this app.
  Future<void> sendEmailCode({required String email});

  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> resetPassword({required String newPassword});

  Future<void> signOut();

  Future<AuthUser?> currentUser();

  Future<AuthUser> updateProfile({required String fullName, String? phone});

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// Whether the account that was just signed up still has to confirm its
  /// email.
  ///
  /// [AuthCubit] asks the repository it was given rather than testing its class,
  /// so a decorator in front of the real repository cannot turn the question
  /// into "no" and send an unconfirmed customer into the app.
  bool get lastSignUpNeedsEmailConfirmation => false;
}
