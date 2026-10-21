import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(AuthInitial());

  final AuthRepository _repository;

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
    );
  }

  Future<void> signInWithGoogle() async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    try {
      final user = await _repository.signInWithGoogle();
      emit(AuthSuccess(user));
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      if (error.message == 'google_sign_in_canceled') {
        emit(AuthInitial());
        return;
      }
      emit(AuthFailure(messageFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected Google sign-in error: $error\n$stackTrace');
      emit(AuthFailure(S.authUnexpected));
    }
  }

  Future<void> signInWithFacebook() =>
      _authenticate(_repository.signInWithFacebook);

  Future<void> signInWithApple() => _authenticate(_repository.signInWithApple);

  Future<void> signOut() async {
    await _repository.signOut();
    emit(AuthInitial());
  }

  Future<void> _authenticate(Future<AuthUser> Function() action) async {
    if (state is AuthLoading) return;
    emit(AuthLoading());
    try {
      final user = await action();
      emit(AuthSuccess(user));
    } on AuthException catch (error) {
      // The provider's English never reaches the customer; each known cause
      // maps to one message in the app's current language.
      emit(AuthFailure(messageFor(error.message)));
    } catch (_) {
      emit(AuthFailure(S.authUnexpected));
    }
  }

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
    if (lower.contains('weak_password') ||
        lower.contains('weak password')) {
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
        lower.contains('google_sign_in_failed')) {
      return S.authGoogleUnavailable;
    }
    return S.authFailed;
  }
}