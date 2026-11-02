import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, {this.session = const SessionRepository()})
    : super(const AuthInitial());

  final AuthRepository _repository;

  /// The markers that decide where the next launch starts.
  final SessionRepository session;

  Future<void> signIn({required String email, required String password}) async {
    if (state is AuthLoading) return;
    await _authenticate(
      () => _repository.signIn(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (state is AuthLoading) return;
    await _authenticate(
      () => _repository.signUp(name: name, email: email, password: password),
      // The provider hands back a customer who still has to confirm the
      // address, and an unconfirmed address is not a session worth recording.
      verificationPending: () => _repository.lastSignUpNeedsEmailConfirmation,
    );
  }

  /// The Google sheet can be dismissed, which is not a failure.
  ///
  /// The provider reports it as an error, so [cancelToken] turns that one token
  /// back into the idle screen instead of an error dialog.
  Future<void> signInWithGoogle() => _authenticate(
    _repository.signInWithGoogle,
    cancelToken: 'google_sign_in_canceled',
  );

  Future<void> signInWithFacebook() =>
      _authenticate(_repository.signInWithFacebook);

  Future<void> signInWithApple() => _authenticate(_repository.signInWithApple);

  /// The customer chose to browse without an account.
  ///
  /// The same markers a sign-in writes are written here, because the point of
  /// skipping is to never be asked again.
  Future<void> skipAuthentication() async {
    if (state is AuthLoading) return;
    emit(const AuthLoading());
    await _recordAuthenticatedSession();
    if (isClosed) return;
    emit(const AuthSkipped());
  }

  /// Signs the customer out, then clears the stored route.
  ///
  /// The route is only cleared after the client sign-out actually succeeded. If
  /// it throws, the customer stays where they are with an explanation rather
  /// than on a screen that claims they are signed out while the session is
  /// still live.
  Future<void> signOut() async {
    if (state is AuthLoading) return;
    emit(const AuthLoading());
    try {
      await _repository.signOut();
    } catch (error) {
      debugPrint('Sign-out failed: $error');
      if (isClosed) return;
      emit(AuthFailure(S.logoutFailed));
      return;
    }
    final cleared = await session.markSignedOutConfirmed();
    if (!cleared) {
      debugPrint('[Auth] signed-out marker could not be persisted.');
    }
    if (isClosed) return;
    emit(const AuthSignedOut());
  }

  Future<void> _authenticate(
    Future<AuthUser> Function() action, {
    bool Function() verificationPending = _nobodyIsPendingVerification,
    String? cancelToken,
  }) async {
    if (state is AuthLoading) return;
    emit(const AuthLoading());
    try {
      final user = await action();
      if (verificationPending()) {
        if (isClosed) return;
        emit(const AuthEmailConfirmationRequired());
        return;
      }
      await _recordAuthenticatedSession();
      if (isClosed) return;
      emit(AuthSuccess(user));
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      if (isClosed) return;
      if (cancelToken != null && error.message == cancelToken) {
        emit(const AuthInitial());
        return;
      }
      // The provider's English never reaches the customer; each known cause
      // maps to one message in the app's current language.
      emit(AuthFailure(messageFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected auth error: $error\n$stackTrace');
      if (isClosed) return;
      emit(AuthFailure(S.authUnexpected));
    }
  }

  /// Writes the markers that keep the customer out of the onboarding on the
  /// next launch, and confirms they landed.
  ///
  /// A marker that will not land is reported, not acted on: the customer *is*
  /// signed in (or chose to browse unsigned), so refusing to let them in would
  /// punish them for a storage failure. The only cost is that the next launch
  /// asks again.
  Future<void> _recordAuthenticatedSession() async {
    final saved = await session.markAuthenticatedConfirmed();
    if (!saved) {
      debugPrint('[Auth] session marker could not be persisted.');
    }
  }

  static bool _nobodyIsPendingVerification() => false;

  /// Maps a provider error onto a customer-facing message.
  ///
  /// Anything unrecognised becomes [S.authFailed] rather than echoing the raw
  /// text, which would put English (or provider jargon) into an Arabic screen.
  /// Matching is done on the lowercased input with `contains`, so both the
  /// stable codes returned by Supabase (e.g. `invalid_credentials`) and the
  /// legacy English messages are handled.
  static String messageFor(String message) {
    final lower = message.toLowerCase().trim();
    if (lower == 'service_unavailable') {
      return S.authServiceUnavailable;
    }
    if (lower == 'recovery_link_required') {
      return S.authRecoveryLinkRequired;
    }
    if (lower.contains('invalid_credentials') ||
        lower.contains('invalid_grant') ||
        lower.contains('invalid login credentials') ||
        lower.contains('invalid password') ||
        lower.contains('invalid email or password') ||
        lower.contains('wrong password')) {
      return S.authInvalidCredentials;
    }
    if (lower.contains('user_not_found') ||
        lower.contains('user not found') ||
        lower.contains('no user')) {
      return S.authUserNotFound;
    }
    if (lower.contains('staff_account') || lower.contains('staff account')) {
      return S.authStaffAccount;
    }
    // Phone sign-in, and it has to be read here: three of its codes end in the
    // word `disabled`, which the banned-account rule below matches on its own,
    // and a customer would be told their number is blocked when the truth is
    // that the door is not open or their code went stale.
    // `phone_provider_disabled`, `otp_disabled` and `signup_disabled` were
    // measured against this project on 2026-11-02; `otp_expired` and
    // `over_sms_send_rate_limit` are the codes the provider documents for a
    // stale code and an exhausted message quota.
    // `email_provider_disabled` and `signups not allowed` are the same answer
    // from the mail door: the dashboard has it closed, which no customer can
    // fix by typing.
    if (lower.contains('phone_provider_disabled') ||
        lower.contains('email_provider_disabled') ||
        lower.contains('signups not allowed') ||
        lower.contains('otp_disabled') ||
        lower.contains('signup_disabled')) {
      return S.authProviderNotEnabled;
    }
    if (lower.contains('otp_expired') || lower.contains('invalid token')) {
      return S.authOtpInvalid;
    }
    if (lower.contains('invalid_phone') || lower.contains('invalid phone')) {
      return S.validPhoneNumber;
    }
    if (lower.contains('over_sms_send_rate_limit')) {
      return S.authTooManyRequests;
    }
    if (lower.contains('sms_send_failed')) {
      return S.authSmsSendFailed;
    }
    if (lower.contains('user_banned') ||
        lower.contains('user disabled') ||
        lower.contains('disabled')) {
      return S.authUserDisabled;
    }
    if (lower.contains('email_exists') ||
        lower.contains('user_already_exists') ||
        lower.contains('already') && lower.contains('registered') ||
        lower.contains('already') && lower.contains('exists') ||
        lower.contains('already in use') ||
        lower.contains('email already')) {
      return S.authEmailInUse;
    }
    if (lower.contains('weak_password') || lower.contains('weak password')) {
      return S.authWeakPassword;
    }
    if (lower.contains('invalid_email') ||
        lower.contains('invalid email') ||
        lower.contains('validation_failed')) {
      return S.authInvalidEmail;
    }
    if (lower.contains('email_not_confirmed') ||
        lower.contains('email not confirmed')) {
      return S.authEmailNotConfirmed;
    }
    if (lower.contains('over_request_rate_limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('too many') ||
        lower.contains('rate limit')) {
      return S.authTooManyRequests;
    }
    if (lower.contains('google_client_configuration_error') ||
        lower.contains('google_sign_in_failed') ||
        lower.contains('google_sign_in_missing_token')) {
      return S.authGoogleUnavailable;
    }
    // Google refused the account on the device, and said why in a code the
    // provider owns. Retrying the same tap cannot help, so the answer names the
    // other door.
    if (lower.contains('google_sign_in_refused')) {
      return S.authGoogleRefused;
    }
    if (lower.contains('google_no_account_on_device')) {
      return S.authGoogleNoAccount;
    }
    // The Supabase dashboard has the provider switched off, or the token was
    // minted by a Google client the project does not know. Either way the
    // customer cannot act on a generic failure, and email is the way in.
    if (lower.contains('provider_not_enabled') ||
        lower.contains('provider_not_supported') ||
        lower.contains('provider not enabled') ||
        lower.contains('provider not supported')) {
      return S.authProviderNotEnabled;
    }
    // Our own backend refusing a token Google actually issued. `nonces
    // mismatch` is the one measured on emulator-5554 on 2026-11-02, when the
    // app still sent a client nonce this path cannot satisfy; `invalid
    // audience` is the same class of answer for a token minted by a client the
    // project does not list. Neither is fixed by tapping again, and both used
    // to land on the generic retry sentence.
    if (lower.contains('nonces mismatch') ||
        lower.contains('invalid audience')) {
      return S.authProviderNotEnabled;
    }
    return S.authFailed;
  }
}
