import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';

class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit(this._repository) : super(const PhoneAuthInitial());

  final AuthRepository _repository;

  Future<void> sendCode({required String phone}) async {
    if (state is PhoneAuthLoading) return;
    emit(const PhoneAuthLoading());
    try {
      await _repository.sendPhoneCode(phone: phone);
      emit(const PhoneAuthCodeSent());
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      emit(PhoneAuthFailure(AuthCubit.messageFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected phone auth error: $error\n$stackTrace');
      emit(PhoneAuthFailure(S.authUnexpected));
    }
  }

  Future<void> verifyCode({
    required String phone,
    required String code,
  }) async {
    if (state is PhoneAuthLoading) return;
    emit(const PhoneAuthLoading());
    try {
      final user = await _repository.verifyPhoneCode(
        phone: phone,
        code: code,
      );
      emit(PhoneAuthSuccess(user));
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      emit(PhoneAuthFailure(AuthCubit.messageFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected phone auth error: $error\n$stackTrace');
      emit(PhoneAuthFailure(S.authUnexpected));
    }
  }

  void reset() => emit(const PhoneAuthInitial());
}
