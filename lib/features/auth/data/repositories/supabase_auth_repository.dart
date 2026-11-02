import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:new_coffee/core/services/shared_pref.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
// The Supabase SDK ships its own AuthUser and AuthException. This layer deals
// in the app's domain types, so the SDK's copies are hidden to keep every
// reference unambiguous.
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

/// The real authentication layer.
///
/// Implements the [AuthRepository] contract against Supabase, so no screen and
/// no cubit changes when it is swapped in for another binding.
///
/// Every method verifies the caller's intent against the server. No method
/// invents a user, and no method accepts an identity the server did not issue.
class SupabaseAuthRepository implements AuthRepository {
  /// [recoverySessionWait] is how long the reset screen waits for the emailed
  /// link; it is a parameter only so a test can prove the wait runs out
  /// without spending twenty seconds doing it.
  SupabaseAuthRepository({Duration? recoverySessionWait})
    : _recoverySessionWait = recoverySessionWait ?? const Duration(seconds: 20);

  final Duration _recoverySessionWait;

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
      if (lowerCode == 'invalid_credentials' || lowerCode == 'invalid_grant') {
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
    if (lowerMessage.contains('email not confirmed')) {
      return 'email not confirmed';
    }
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
      // The account's own number first: for a phone sign-in it is the value the
      // provider confirmed, while `user_metadata.phone` is only what a signup
      // form chose to send.
      phone: user.phone ?? metadata?['phone']?.toString(),
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
      await _requireCustomerAccount(user.id);
      final domain = _toDomain(user);
      await _cacheProfile(domain);
      return domain;
    } catch (error) {
      if (error is AuthException) rethrow;
      throw AuthException(_mapAuthError(error));
    }
  }

  /// Closes the session and refuses it when the signed-in uid has no row in
  /// identity.profiles.
  ///
  /// 188_separate_customer_and_staff_accounts.sql makes that table the customer
  /// population and identity.staff_members the admin one, so a staff login has
  /// no customer row to order under. Without this check the customer app would
  /// sign the manager in and then fail on the first screen that needs a
  /// customer, which reads like broken data rather than like the wrong app.
  Future<void> _requireCustomerAccount(String uid) async {
    final rows = await _client
        .from('profiles')
        .select('id')
        .eq('id', uid)
        .limit(1);
    if (rows.isNotEmpty) return;
    try {
      await _client.auth.signOut();
    } catch (_) {
      // The session was never usable; the refusal is the answer either way.
    }
    throw const AuthException('staff account');
  }

  @override
  Future<AuthUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _guard;
    _signUpNeedsConfirmation = false;
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
      // The answer is the *response*, and nothing else. `_client.auth.currentUser`
      // stays null in exactly this case — gotrue only stores a session when the
      // server handed one over — so reading the client here reported a brand new
      // unconfirmed address as a signed-in customer, sent them to the store with
      // no session, and left the "check your inbox" screen unreachable.
      _signUpNeedsConfirmation = response.session == null;
      final domain = _toDomain(user);
      // An address that has not been confirmed is not a session, and its name
      // and email have no business sitting on this device yet.
      if (!_signUpNeedsConfirmation) await _cacheProfile(domain);
      return domain;
    } catch (error) {
      if (error is AuthException) rethrow;
      throw AuthException(_mapAuthError(error));
    }
  }

  /// Whether the signed-up address still needs confirming.
  /// The UI uses this to route to "check your inbox" instead of the home page.
  ///
  /// Set by the [signUp] call itself, because the signed-in user the app would
  /// otherwise ask does not exist yet while the address is unconfirmed.
  @override
  bool get lastSignUpNeedsEmailConfirmation => _signUpNeedsConfirmation;

  bool _signUpNeedsConfirmation = false;

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

    // Throws unless the emailed link was opened; the update below is allowed
    // only for that session.
    await _requireRecoverySession();
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Returns the recovery session, waiting briefly for the redirect that may
  /// still be in flight. Throws a clear, actionable error when there is none.
  Future<Session> _requireRecoverySession() async {
    // A session that is merely live is not a recovery session.
    //
    // The customer who is signed in already changes their password from the
    // settings screen, after proving the current one. This screen exists for
    // the customer who cannot, and the emailed link is its only credential, so
    // accepting any session here would let an unlocked phone rewrite the
    // password of whoever it happens to be signed in as.
    if (SupabaseService.passwordRecoverySeen) {
      final current = _client.auth.currentSession;
      if (current != null) return current;
    }

    // If the app was just opened from the emailed link, the event may not have
    // been delivered yet.
    final pending = _recoveryCompleter ??= Completer<Session>();
    _recoverySubscription ??= _client.auth.onAuthStateChange.listen((event) {
      if (event.event != AuthChangeEvent.passwordRecovery) return;
      if (event.session != null && !pending.isCompleted) {
        pending.complete(event.session);
      }
    });

    try {
      return await pending.future.timeout(
        _recoverySessionWait,
        // A token, not the sentence: the cubit owns the wording, and an
        // English sentence here would reach an Arabic screen as a generic
        // "something went wrong".
        onTimeout: () => throw const AuthException('recovery_link_required'),
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
    // The token of this device is removed while the session still exists:
    // the server can only give the token back to the customer it belongs to.
    // Without this the notifications of the customer who signs out would keep
    // arriving on a phone the next person uses.
    await PushService.unregister();
    await _client.auth.signOut();
    // A Google account that was used in this process stays remembered by
    // Credential Manager after the Supabase session is gone, so the next person
    // to hold the phone is offered the previous customer's account. On Android
    // `signOut()` is exactly `CredentialManager.clearCredentialState()`: it
    // forgets the app's association, and does not revoke the customer's grant.
    // Only a process that actually initialised the plugin may call it, and a
    // failure here must not pretend the logout did not happen.
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        // The Supabase session really ended, so the logout must not be
        // reported as a failure - but the next person on this phone may still
        // be offered this account, and that has to be readable.
        debugPrint('[GoogleSignIn] credential state not cleared: $error');
      }
    }
    // The profile cache is this customer's name, email and phone in plain text
    // on the device. The session is gone now, so leaving it behind would show
    // the next person's identity file on a phone the previous customer handed
    // over.
    await _clearCachedProfile();
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
    //
    // Passed through exactly as typed, the way sign-in and sign-up do it: a
    // password whose first or last character is a space is a valid one, and
    // trimming here would report the customer's own password as wrong.
    await _client.auth.signInWithPassword(
      email: user.email!,
      password: oldPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    await _client.auth.refreshSession();
  }

  /// Previously hardcoded to null, so the app never knew who was signed in.
  @override
  Future<AuthUser?> currentUser() async {
    if (!SupabaseService.isReady) return null;
    final user = _client.auth.currentUser;
    if (user == null) {
      await _clearCachedProfile();
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

  Future<void> _clearCachedProfile() =>
      SharedPref.setValue(key: _profileCacheKey, value: '');

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

  // -------------------------------------------------------------------------
  // Social providers
  // -------------------------------------------------------------------------

  static bool _googleInitialized = false;

  @override
  Future<AuthUser> signInWithGoogle() async {
    _guard;
    GoogleSignInAccount account;
    try {
      // Setup can refuse before a single sheet opens: an OAuth client that no
      // Google app recognises fails inside `initialize`, not inside
      // `authenticate`. Keeping it in this handler is what makes that failure
      // read as "Google sign-in is unavailable" instead of the catch-all.
      await _ensureGoogleInitialized();
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      _logGoogleFailure(
        'GoogleSignInException',
        error.code.name,
        error.description,
      );
      if (error.code == GoogleSignInExceptionCode.canceled) {
        // Credential Manager reports two very different things as `canceled`:
        // the customer closing the account sheet, and the framework refusing
        // the account it was given. Only the first is a dismissal. The second
        // arrives with the provider's own reason in the message -
        // `[16] Account reauth failed` for a certificate or client that Google
        // does not accept - and going silent there leaves the customer tapping
        // the button again and again for nothing.
        final reason = credentialManagerReason(error.description);
        if (reason == null) {
          throw const AuthException('google_sign_in_canceled');
        }
        throw AuthException('google_sign_in_refused: $reason');
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        // The OAuth client that matches this build's signing certificate is
        // missing or wrong. Debug and release are signed with different
        // certificates, so each one needs its own SHA-1 registered with the
        // Android OAuth client.
        throw const AuthException('google_client_configuration_error');
      }
      // A phone with no Google account on it is reported as an unknown error
      // with the plugin's own sentence in front of it. It is not a retryable
      // failure, and "please try again" is the wrong advice.
      final description = error.description ?? '';
      if (description.contains('No credential available')) {
        throw const AuthException('google_no_account_on_device');
      }
      throw AuthException('google_sign_in_failed: ${error.code.name}');
    } on PlatformException catch (error) {
      // Credential Manager reports a misconfigured client as a platform error
      // rather than a GoogleSignInException, so this branch is what a release
      // build actually hits.
      _logGoogleFailure('PlatformException', error.code, error.message);
      throw AuthException('google_sign_in_failed: ${error.code}');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _logGoogleFailure('MissingIdToken', account.id, 'no id token issued');
      throw const AuthException('google_sign_in_missing_token');
    }
    // No nonce is sent to Supabase here, and that is deliberate.
    //
    // Measured on emulator-5554 on 2026-11-02 with a correctly registered
    // Android OAuth client: Credential Manager issues a fresh ID token
    // (`iat` one second before the exchange) whose `nonce` claim is its own
    // value, not SHA-256 of the nonce passed to `GoogleSignIn.initialize` -
    // claim `6f4f02d1…` against local SHA-256 `7c7d8ba1…`. GoTrue compares the
    // two and refuses the exchange with `nonces mismatch`, so a client nonce
    // on this path can never be satisfied. Supabase's own native Flutter
    // sample sends no nonce either; the token is still bound to this app by
    // `aud` (the web client id) and verified by Google's signature.
    try {
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('google_sign_in_missing_token');
      }
      // The same refusal the email password path applies: a Google account that
      // belongs to staff has no customer row, and letting it in produces a
      // broken store instead of a clear answer.
      await _requireCustomerAccount(user.id);
      final domain = _toDomain(user);
      await _cacheProfile(domain);
      return domain;
    } on AuthException {
      // Already an app token, including the staff refusal above.
      rethrow;
    } catch (error) {
      // The SDK's own AuthException is a different class from this app's — it
      // is hidden in the import above — so a refused exchange ("provider not
      // enabled", a rejected token, a dropped connection) comes through here
      // and is normalised like every other Supabase answer.
      throw AuthException(_mapAuthError(error));
    }
  }

  /// Writes a Google Sign-In failure where the person debugging it will look.
  ///
  /// Measured on emulator-5554: a `developer.log` line from this file never
  /// reached logcat at all, while the cubit's `debugPrint` did - `dart:developer`
  /// hands its output to a connected DevTools session, and a phone driven
  /// straight from `adb` has none. `debugPrint` is throttled but it is what
  /// actually arrives, in debug and in release.
  static void _logGoogleFailure(String kind, String code, String? description) {
    debugPrint(
      '[GoogleSignIn] Google sign-in failed: kind=$kind code=$code'
      '${description == null || description.isEmpty ? '' : ' description=$description'}',
    );
  }

  /// The Credential Manager reason hidden inside a `canceled` message, or null
  /// when the customer really did dismiss the sheet.
  ///
  /// The androidx exception writes its own reason code into the message it
  /// hands to the plugin — `[16] Account reauth failed.` — while a plain
  /// dismissal says `User canceled activity.` with no code. Exposed so a test
  /// can prove the two are told apart without a device.
  @visibleForTesting
  static String? credentialManagerReason(String? description) {
    final text = (description ?? '').trim();
    if (text.isEmpty) return null;
    final reason = RegExp(r'\[(\d+)\]\s*([^.\]]+)').firstMatch(text);
    if (reason == null) return null;
    return '${reason.group(1)} ${reason.group(2)!.trim()}';
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
    );
    _googleInitialized = true;
  }

  // -------------------------------------------------------------------------
  // Phone
  //
  // The number is the credential, the message is the proof of it. Two calls
  // talk to the provider: one asks for a code, one trades the typed code for a
  // session. Both normalise the number first, because the provider only reads
  // E.164 and the customer types whatever they know by heart.
  //
  // Delivery of the message itself is server-side: Supabase calls the
  // `send-sms` Edge Function (supabase/functions/send-sms) as its Send SMS
  // hook, and the provider key never comes near this app.
  // -------------------------------------------------------------------------

  @override
  Future<void> sendPhoneCode({required String phone}) async {
    _guard;
    final e164 = AuthFormRules.e164Of(phone);
    if (e164 == null) throw const AuthException('invalid phone number');
    try {
      // `create_user` is left at the SDK default: a code sent to a number that
      // has never been seen is how a new customer is created, and the screen
      // does not ask them to sign up separately.
      await _client.auth.signInWithOtp(phone: e164);
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<AuthUser> verifyPhoneCode({
    required String phone,
    required String code,
  }) async {
    _guard;
    final e164 = AuthFormRules.e164Of(phone);
    if (e164 == null) throw const AuthException('invalid phone number');
    try {
      final response = await _client.auth.verifyOTP(
        phone: e164,
        token: code.trim(),
        type: OtpType.sms,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('No user returned for this code.');
      }
      // The same refusal the email and Google paths apply: a number that
      // belongs to staff has no customer row, and letting it in produces a
      // broken store instead of a clear answer.
      await _requireCustomerAccount(user.id);
      await _storeVerifiedPhone(user.id, e164);
      final domain = _toDomain(user);
      await _cacheProfile(domain);
      return domain;
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  /// The number the customer just proved, in the row the app reads.
  ///
  /// `identity.handle_new_user()` (003_identity_01_profiles.sql) copies the
  /// email of a new account into identity.profiles and knows nothing about a
  /// phone, so a customer who arrives by SMS has a session, a profile row, and
  /// no number anywhere the profile screen or the admin panel looks. The
  /// trigger is not rewritten for this: the session that was just issued *is*
  /// the proof that the number belongs to them, and `profiles_update_own`
  /// (019_rls_01_identity.sql) lets them write their own row.
  ///
  /// An existing number is never overwritten - a customer who added one from
  /// their profile keeps what they typed.
  Future<void> _storeVerifiedPhone(String uid, String phone) async {
    try {
      final row = await _client
          .from('profiles')
          .select('phone')
          .eq('id', uid)
          .maybeSingle();
      final current = (row?['phone'] ?? '').toString().trim();
      if (current.isNotEmpty) return;
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'phone': phone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', uid);
    } catch (error) {
      // The session is real either way; this only fills a display value.
      debugPrint('[Auth] verified phone could not be stored: $error');
    }
  }

  // -------------------------------------------------------------------------
  // E-mail code
  //
  // The same two calls the phone path makes, with the mailbox as the delivery:
  // one asks the provider for a code, one trades the typed code for a session.
  //
  // Whether the message carries a code or a link is decided by the server's
  // template (`{{ .Token }}` sends the code, `{{ .ConfirmationURL }}` sends a
  // link), and who delivers it is decided by the project's SMTP settings. The
  // app only ever handles the code the customer reads out of the mail, so no
  // provider key sits in this binary.
  // -------------------------------------------------------------------------

  @override
  Future<void> sendEmailCode({required String email}) async {
    _guard;
    final address = email.trim();
    if (AuthFormRules.email(address) != null) {
      throw const AuthException('invalid email');
    }
    try {
      // A code requested for an address the project has never seen creates the
      // account, exactly like the phone path: `identity.handle_new_user()`
      // copies it into identity.profiles, so the customer has a row to order
      // under without going through the password form first.
      await _client.auth.signInWithOtp(email: address);
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<AuthUser> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    _guard;
    final address = email.trim();
    if (AuthFormRules.email(address) != null) {
      throw const AuthException('invalid email');
    }
    try {
      final response = await _client.auth.verifyOTP(
        email: address,
        token: code.trim(),
        type: OtpType.email,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('No user returned for this code.');
      }
      // The same refusal the phone and Google paths apply: an address that
      // belongs to staff has no customer row.
      await _requireCustomerAccount(user.id);
      final domain = _toDomain(user);
      await _cacheProfile(domain);
      return domain;
    } on AuthException {
      rethrow;
    } catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  /// The two providers that still say they are missing, instead of faking a
  /// success the screens would then have to unwind.
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
}
