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
      emit(AuthFailure(_messageFor(error.message)));
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
    emit(AuthLoading());
    try {
      final user = await action();
      emit(AuthSuccess(user));
    } on AuthException catch (error) {
      // The provider's English never reaches the customer; each known cause
      // maps to one message in the app's current language.
      emit(AuthFailure(_messageFor(error.message)));
    } catch (_) {
      emit(AuthFailure(S.authUnexpected));
    }
  }

  /// Maps a provider error onto a customer-facing message.
  ///
  /// Anything unrecognised becomes [S.authFailed] rather than echoing the raw
  /// text, which would put English (or provider jargon) into an Arabic screen.
  static String _messageFor(String message) {
    switch (message.toLowerCase()) {
      case 'invalid login credentials':
      case 'invalid password':
        return S.authInvalidCredentials;
      case 'user not found':
        return S.authUserNotFound;
      case 'user disabled':
        return S.authUserDisabled;
      case 'email already in use':
      case 'email already exists':
        return S.authEmailInUse;
      case 'weak password':
        return S.authWeakPassword;
      case 'invalid email':
        return S.authInvalidEmail;
      default:
        return S.authFailed;
    }
  }
}