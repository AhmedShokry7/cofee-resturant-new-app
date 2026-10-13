import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';

part 'password_reset_state.dart';

class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._repository) : super(PasswordResetInitial());

  final AuthRepository _repository;

  Future<void> sendEmail({required String email}) async {
    emit(PasswordResetLoading());
    try {
      await _repository.sendPasswordResetEmail(email: email);
      emit(PasswordResetEmailSent());
    } on AuthException catch (error) {
      emit(PasswordResetFailure(error.message));
    } catch (error) {
      emit(PasswordResetFailure(error.toString()));
    }
  }

  Future<void> resetPassword({required String password}) async {
    emit(PasswordResetLoading());
    try {
      await _repository.resetPassword(newPassword: password);
      emit(PasswordResetSuccess());
    } on AuthException catch (error) {
      emit(PasswordResetFailure(error.message));
    } catch (error) {
      emit(PasswordResetFailure(error.toString()));
    }
  }
}
