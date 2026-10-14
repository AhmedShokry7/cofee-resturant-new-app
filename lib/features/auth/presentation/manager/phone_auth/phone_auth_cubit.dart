import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/models/auth_exception.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';

class PhoneAuthCubit extends Cubit<PhoneAuthState> {
  PhoneAuthCubit(this._repository) : super(const PhoneAuthInitial());

  final AuthRepository _repository;

  Future<void> sendCode({required String phone}) async {
    emit(const PhoneAuthLoading());
    try {
      await _repository.sendPhoneCode(phone: phone);
      emit(const PhoneAuthCodeSent());
    } on AuthException catch (error) {
      emit(PhoneAuthFailure(error.message));
    } catch (error) {
      emit(PhoneAuthFailure(error.toString()));
    }
  }

  Future<void> verifyCode({
    required String phone,
    required String code,
  }) async {
    emit(const PhoneAuthLoading());
    try {
      final user = await _repository.verifyPhoneCode(
        phone: phone,
        code: code,
      );
      emit(PhoneAuthSuccess(user));
    } on AuthException catch (error) {
      emit(PhoneAuthFailure(error.message));
    } catch (error) {
      emit(PhoneAuthFailure(error.toString()));
    }
  }

  void reset() => emit(const PhoneAuthInitial());
}
