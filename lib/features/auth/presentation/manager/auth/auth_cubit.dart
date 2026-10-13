import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    try {
      final user = await action();
      emit(AuthSuccess(user));
    } on AuthException catch (error) {
      emit(AuthFailure(error.message));
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }
}
