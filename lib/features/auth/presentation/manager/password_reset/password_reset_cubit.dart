import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';

part 'password_reset_state.dart';

class PasswordResetCubit extends Cubit<PasswordResetState> {
  PasswordResetCubit(this._repository) : super(PasswordResetInitial());

  final AuthRepository _repository;

  Future<void> sendEmail({required String email}) async {
    if (state is PasswordResetLoading) return;
    emit(PasswordResetLoading());
    try {
      await _repository.sendPasswordResetEmail(email: email);
      if (isClosed) return;
      emit(PasswordResetEmailSent());
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      if (isClosed) return;
      emit(PasswordResetFailure(AuthCubit.reasonFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected password reset error: $error\n$stackTrace');
      if (isClosed) return;
      emit(PasswordResetFailure(AppCopy.authUnexpected));
    }
  }

  Future<void> resetPassword({required String password}) async {
    if (state is PasswordResetLoading) return;
    emit(PasswordResetLoading());
    try {
      await _repository.resetPassword(newPassword: password);
      if (isClosed) return;
      emit(PasswordResetSuccess());
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      if (isClosed) return;
      emit(PasswordResetFailure(AuthCubit.reasonFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected password reset error: $error\n$stackTrace');
      if (isClosed) return;
      emit(PasswordResetFailure(AppCopy.authUnexpected));
    }
  }
}
