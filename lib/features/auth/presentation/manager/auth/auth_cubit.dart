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

  Future<void> signIn({required String email, required String password}) =>
      _authenticate(
        () => _repository.signIn(email: email, password: password),
      );

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _authenticate(
        () => _repository.signUp(name: name, email: email, password: password),
      );

  Future<void> signInWithGoogle() =>
      _authenticate(_repository.signInWithGoogle);

  Future<void> signInWithFacebook() =>
      _authenticate(_repository.signInWithFacebook);

  Future<void> signInWithApple() => _authenticate(_repository.signInWithApple);

  Future<void> signOut() async {
    await _repository.signOut();
    emit(AuthInitial());
  }

  Future<void> _authenticate(Future<AuthUser> Function() action) async {
    emit(AuthLoading());
    print('[Auth] Starting authentication action...');
    try {
      final user = await action();
      emit(AuthSuccess(user));
      print('[Auth] ✅ Authentication successful!');
    } on AuthException catch (error) {
      print('[Auth] ❌ AuthException caught: ${error.message}');
      // The provider's English never reaches the customer; each known cause
      // maps to one message in the app's current language.
      emit(AuthFailure(_messageFor(error.message)));
    } catch (exception) {
      print('[Auth] ❌ Unexpected exception caught: $exception');
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