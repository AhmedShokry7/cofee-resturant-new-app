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
    print('[Auth] Starting authentication action...');
    try {
      final user = await action();
      emit(AuthSuccess(user));
      print('[Auth] ✅ Authentication successful!');
    } on AuthException catch (error) {
      print('[Auth] ❌ AuthException caught: ${error.message}');
      // Clear Arabic messages for common auth errors
      String arabicMessage;
      switch (error.message.toLowerCase()) {
        case 'invalid login credentials':
        case 'invalid password':
          arabicMessage = 'بيانات الدخول غير صحيحة، برجاء التحقق من الإيميل وكلمة المرور';
          break;
        case 'user not found':
          arabicMessage = 'هذا الإيميل غير مسجل في قاعدة البيانات، برجاء التسجيل أولًا';
          break;
        case 'user disabled':
          arabicMessage = 'هذا الحساب已被已被禁用، برجاء التواصل مع الدعم';
          break;
        case 'email already in use':
        case 'email already exists':
          arabicMessage = 'هذا الإيميلAlready مسجل، برجاء استخدام إيميل مختلف أو الدخول';
          break;
        case 'weak password':
          arabicMessage = 'كلمة المرور ضعيفة، برجاء استخدام كلمة مرور أطول وأكثر أمانًا';
          break;
        case 'invalid email':
          arabicMessage = 'إيميل غير صحيح، برجاء إدخال إيميل صحيح';
          break;
        default:
          arabicMessage = 'حدث خطأ أثناء الدخول: ${error.message}';
      }
      emit(AuthFailure(arabicMessage));
    } catch (exception) {
      print('[Auth] ❌ Unexpected exception caught: $exception');
      emit(AuthFailure('حدث خطأ غير متوقع، برجاء المحاولة senare'));
    }
  }
}