import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/services/shared_pref.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  /// Translates a Supabase auth error into a stable, lowercased token the
  /// cubit can map onto a customer-facing message. Prefers the SDK's code
  /// (stable) and falls back to the message text.
  static String _mapAuthError(Object error) {
    String code = '';
    String message = error.toString();
    try {
      final dynamic e = error;
      final c = e.code;
      if (c is String) code = c;
      final m = e.message;
      if (m is String && m.isNotEmpty) message = m;
    } catch (_) {}
    final lowerCode = code.toLowerCase();
    final lowerMessage = message.toLowerCase();
    if (lowerCode.isNotEmpty) {
      if (lowerCode == 'invalid_credentials' ||
          lowerCode == 'invalid_grant') {
        return 'invalid login credentials';
      }
      return lowerCode;
    }
    if (lowerMessage.contains('invalid login credentials') ||
        lowerMessage.contains('invalid password') ||
        lowerMessage.contains('invalid email or password')) {
      return 'invalid login credentials';
    }
    if (lowerMessage.contains('user not found')) return 'user not found';
    if (lowerMessage.contains('email not confirmed')) return 'email not confirmed';
    if (lowerMessage.contains('already') &&
        (lowerMessage.contains('registered') ||
            lowerMessage.contains('exists'))) {
      return 'user already exists';
    }
    if (lowerMessage.contains('weak password')) return 'weak password';
    if (lowerMessage.contains('invalid email')) return 'invalid email';
    if (lowerMessage.contains('too many') ||
        lowerMessage.contains('rate limit')) {
      return 'over_request_rate_limit';
    }
    return lowerMessage.isNotEmpty ? lowerMessage : 'auth failed';
  }

  AuthUser _toDomain(User user) {
    final metadata = user.userMetadata;
    final localPart = user.email?.split('@').first;
    final name = metadata?['full_name'] ?? metadata?['name'] ?? localPart;
    return AuthUser(
      id: user.id,
      name: name,
      email: user.email,
      phone: metadata?['phone']?.toString(),
    );
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _guard;
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('Sign in failed: no user returned.');
      }
      final domain = _toDomain(user);
      await _cacheProfile(domain);
      return domain;
    } catch (error) {
      if (error is AuthException) rethrow;
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _guard;
    try {
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
      // Supabase returns the user with an empty identities list when the
      // address is already registered (email confirmation on), instead of
      // throwing. Surface that as a clear "already registered" error.
      if (user.identities == null || user.identities!.isEmpty) {
        throw const AuthException('user already exists');
      }
      final domain = _toDomain(user);
      await _cacheProfile(domain);
      return domain;
    } catch (error) {
      if (error is AuthException) rethrow;
      throw AuthException(_mapAuthError(error));
    }
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
    // Returning quietly used to let the settings screen navigate to the auth page
    // as if the session had ended, while the client still held a live one and
    // the customer was never actually signed out. Failing loudly keeps them
    // signed in knowingly instead.
    if (!SupabaseService.isReady) {
      throw AuthException(
        'Signing out needs a configured Supabase backend.\n'
        '${AppConfig.missingConfigurationMessage}',
      );
    }
    await _client.auth.signOut();
  }

  @override
  Future<AuthUser> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    _guard;
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in.');
    await _client.auth.updateUser(
      UserAttributes(data: <String, dynamic>{'full_name': fullName.trim()}),
    );
    await _client.auth.refreshSession();
    await _client
        .from('profiles')
        .update(<String, dynamic>{
          'full_name': fullName.trim(),
          if (phone != null) 'phone': phone.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);
    final refreshed = _client.auth.currentUser;
    if (refreshed == null) throw const AuthException('Profile update failed.');
    final result = AuthUser(
      id: refreshed.id,
      name: fullName.trim(),
      email: refreshed.email,
      phone: phone?.trim(),
    );
    await _cacheProfile(result);
    return result;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _guard;
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('Not signed in.');
    }
    // Verify the current password before allowing a change.
    await _client.auth.signInWithPassword(
      email: user.email!,
      password: oldPassword.trim(),
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword.trim()));
    await _client.auth.refreshSession();
  }

  /// Previously hardcoded to null, so the app never knew who was signed in.
  @override
  Future<AuthUser?> currentUser() async {
    if (!SupabaseService.isReady) return null;
    final user = _client.auth.currentUser;
    if (user == null) {
      await SharedPref.setValue(key: _profileCacheKey, value: '');
      return null;
    }
    final cached = await _cachedProfile();
    if (cached != null && cached.id == user.id) {
      // Refresh in background without blocking the UI.
      unawaited(_refreshProfileCache(user));
      return cached;
    }
    final domain = _toDomain(user);
    try {
      final row = await _client
          .from('profiles')
          .select('phone')
          .eq('id', user.id)
          .maybeSingle();
      final phone = row?['phone']?.toString();
      final result = (phone != null && phone.isNotEmpty)
          ? AuthUser(
              id: domain.id,
              name: domain.name,
              email: domain.email,
              phone: phone,
            )
          : domain;
      await _cacheProfile(result);
      return result;
    } catch (_) {
      await _cacheProfile(domain);
      return domain;
    }
  }

  static const String _profileCacheKey = 'cached_profile_v1';

  Future<void> _cacheProfile(AuthUser user) async {
    await SharedPref.setValue(
      key: _profileCacheKey,
      value: jsonEncode(<String, dynamic>{
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
      }),
    );
  }

  Future<AuthUser?> _cachedProfile() async {
    final raw = await SharedPref.getValue(key: _profileCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AuthUser(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString(),
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshProfileCache(User user) async {
    try {
      final row = await _client
          .from('profiles')
          .select('phone, full_name')
          .eq('id', user.id)
          .maybeSingle();
      final domain = _toDomain(user);
      final phone = row?['phone']?.toString();
      final name = row?['full_name']?.toString();
      await _cacheProfile(
        AuthUser(
          id: domain.id,
          name: (name != null && name.isNotEmpty) ? name : domain.name,
          email: domain.email,
          phone: (phone != null && phone.isNotEmpty) ? phone : domain.phone,
        ),
      );
    } catch (_) {}
  }

  /// Auth state changes, for an app-wide session bloc later.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // -------------------------------------------------------------------------
  // Not implemented. Each says so plainly instead of faking a success.
  // -------------------------------------------------------------------------

  static bool _googleInitialized = false;
  static String? _googleNonce;

  @override
  Future<AuthUser> signInWithGoogle() async {
    _guard;
    await _ensureGoogleInitialized();
    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      debugPrint(
        'GoogleSignInException: code=${error.code.name} desc=${error.description}',
      );
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('google_sign_in_canceled');
      }
      throw AuthException(
        'Google sign-in failed: ${error.description ?? error.code.name}',
      );
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google sign-in failed: missing ID token.');
    }
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: _googleNonce,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Google sign-in failed: no user returned.');
    }
    final domain = _toDomain(user);
    await _cacheProfile(domain);
    return domain;
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    _googleNonce = _generateNonce();
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
      nonce: _googleNonce,
    );
    _googleInitialized = true;
  }

  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

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
  }) => Future.error(AuthException(_phoneMessage));

  static const String _phoneMessage =
      'Phone sign-in is deferred (DATABASE_SPEC.md section 10.4). It needs an '
      'Edge Function and an SMS provider before it can be enabled.';

  void dispose() {
    _recoverySubscription?.cancel();
    _recoverySubscription = null;
    _recoveryCompleter = null;
  }
}


