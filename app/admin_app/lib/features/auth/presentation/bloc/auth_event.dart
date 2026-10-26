import 'package:equatable/equatable.dart';

/// الأحداث التي تقود دورة حياة جلسة الموظف.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// يُطلب فحص الجلسة المحفوظة عند تشغيل التطبيق.
final class AuthSessionCheckRequested extends AuthEvent {
  const AuthSessionCheckRequested();
}

/// أُرسل نموذج الدخول بالبريد وكلمة المرور.
final class AuthSignInSubmitted extends AuthEvent {
  const AuthSignInSubmitted({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => <Object?>[email, password];
}

/// يُطلب إنهاء الجلسة الحالية.
final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// يُطلب إظهار أو إخفاء كلمة المرور في النموذج.
final class AuthPasswordVisibilityToggled extends AuthEvent {
  const AuthPasswordVisibilityToggled();
}
