import 'dart:async';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
// The Supabase SDK ships its own AuthUser and AuthException. This layer deals
// in the app's domain types, so the SDK's copies are hidden to keep every
// reference unambiguous.
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

/// The real authentication layer.
///
/// Implements the same [AuthRepository] contract that AuthRepositoryImpl
/// faked, so no screen and no cubit changes. Swapping the binding in
/// app_providers.dart is the only edit required.
///
/// Every method verifies the caller's intent against the server. No method
/// invents a user, and no method accepts an identity the server did not issue.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository();

  /// Completes when Supabase reports a PASSWORD_RECOVERY event, which happens
  /// when the user returns from the emailed reset link.
  Completer<Session>? _recoveryCompleter;

  StreamSubscription<AuthState>? _recoverySubscription;

  AuthRepository get _guard {
    if (!SupabaseService.isReady) {
      throw AuthException(
        'Supabase is not configured. ${AppConfig.missingConfigurationMessage}',
      );
    }
    return this;
  }

  SupabaseClient get _client {
    if (!SupabaseService.isReady) {
      throw AuthException(
        'Supabase is not configured. ${AppConfig.missingConfigurationMessage}',
      );
    }
    return SupabaseService.client;
  }

  AuthUser _toDomain(User user) {
    final metadata = user.userMetadata;
    final localPart = user.email?.split('@').first;
    final name = metadata?['full_name'] ?? metadata?['name'] ?? localPart;
    return AuthUser(id: user.id, name: name, email: user.email);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _guard;
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign in failed: no user returned.');
    }
    return _toDomain(user);
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _guard;
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      // identity.handle_new_user() reads this to create identity.profiles.
      data: {'full_name': name.trim()},
      // With email confirmation on, Supabase returns the user but no session.
      emailRedirectTo: AppConfig.passwordRecoveryRedirect.isEmpty
          ? null
          : AppConfig.passwordRecoveryRedirect,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign up failed: no user returned.');
    }
    return _toDomain(user);
  }

  /// Whether the signed-up address still needs confirming.
  /// The UI uses this to route to "check your inbox" instead of the home page.
  bool get lastSignUpNeedsEmailConfirmation {
    final user = _client.auth.currentUser;
    return user != null && user.emailConfirmedAt == null;
  }

  // -------------------------------------------------------------------------
  // Password reset
  //
  // The old flow navigated straight from "forgot password" to "set password"
  // with no token, which would have let anyone reset anyone's password.
  // Now the email carries a link, the link establishes a recovery session, and
  // only that session may set a password.
  // -------------------------------------------------------------------------

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    _guard;
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.passwordRecoveryRedirect.isEmpty
          ? null
          : AppConfig.passwordRecoveryRedirect,
    );
    // Supabase deliberately does not report whether the address exists.
  }

  @override
  Future<void> resetPassword({required String newPassword}) async {
    _guard;

    final session = await _requireRecoverySession();
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    _recoveryCompleter?.complete(session);
    _recoveryCompleter = null;
  }

  /// Returns the recovery session, waiting briefly for the redirect that may
  /// still be in flight. Throws a clear, actionable error when there is none.
  Future<Session> _requireRecoverySession() async {
    final current = _client.auth.currentSession;
    if (current != null) return current;

    // If the app was just opened from the emailed link, the event may not have
    // been delivered yet.
    _recoverySubscription ??= _client.auth.onAuthStateChange.listen((event) {
      if (event.session != null && !_recoveryCompleter!.isCompleted) {
        _recoveryCompleter!.complete(event.session);
      }
    });

    final pending = _recoveryCompleter ??= Completer<Session>();
    try {
      return await pending.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const AuthException(
          'Open the reset link from your email first, then set the new '
          'password. This screen cannot change a password without that link.',
        ),
      );
    } finally {
      await _recoverySubscription?.cancel();
      _recoverySubscription = null;
      _recoveryCompleter = null;
    }
  }

  @override
  Future<void> signOut() async {
    if (!SupabaseService.isReady) return;
    await _client.auth.signOut();
  }

  /// Previously hardcoded to null, so the app never knew who was signed in.
  @override
  Future<AuthUser?> currentUser() async {
    if (!SupabaseService.isReady) return null;
    final user = _client.auth.currentUser;
    return user == null ? null : _toDomain(user);
  }

  /// Auth state changes, for an app-wide session bloc later.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // -------------------------------------------------------------------------
  // Not implemented. Each says so plainly instead of faking a success.
  // -------------------------------------------------------------------------

  @override
  Future<AuthUser> signInWithGoogle() =>
      Future.error(AuthException(_socialMessage('Google')));

  @override
  Future<AuthUser> signInWithFacebook() =>
      Future.error(AuthException(_socialMessage('Facebook')));

  @override
  Future<AuthUser> signInWithApple() =>
      Future.error(AuthException(_socialMessage('Apple')));

  String _socialMessage(String provider) =>
      '$provider sign-in is not configured yet. Add the provider in the '
      'Supabase dashboard and the matching Flutter SDK before enabling the '
      'button.';

  @override
  Future<void> sendPhoneCode({required String phone}) =>
      Future.error(AuthException(_phoneMessage));

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) =>
      Future.error(AuthException(_phoneMessage));

  static const String _phoneMessage =
      'Phone sign-in is deferred (DATABASE_SPEC.md section 10.4). It needs an '
      'Edge Function and an SMS provider before it can be enabled.';

  void dispose() {
    _recoverySubscription?.cancel();
    _recoverySubscription = null;
    _recoveryCompleter = null;
  }
}