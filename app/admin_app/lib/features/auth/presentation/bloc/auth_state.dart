import 'package:equatable/equatable.dart';

import 'package:admin_app/core/error/failure.dart';
import 'package:admin_app/features/auth/domain/entities/admin_session.dart';

/// الحالات التي تمر بها شاشة المصادقة.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// تُفحص الجلسة المحفوظة قبل تحديد الشاشة الأولى.
final class AuthChecking extends AuthState {
  const AuthChecking();
}

/// لا توجد جلسة صالحة، وشاشة الدخول ظاهرة.
final class AuthSignedOut extends AuthState {
  const AuthSignedOut({
    this.failure,
    this.isSubmitting = false,
    this.obscurePassword = true,
  });

  final Failure? failure;
  final bool isSubmitting;
  final bool obscurePassword;

  AuthSignedOut copyWith({
    Failure? failure,
    bool clearFailure = false,
    bool? isSubmitting,
    bool? obscurePassword,
  }) {
    return AuthSignedOut(
      failure: clearFailure ? null : failure ?? this.failure,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }

  @override
  List<Object?> get props => <Object?>[failure, isSubmitting, obscurePassword];
}

/// جلسة موظف صالحة ومتحققة من سجل الموظف.
final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session);

  final AdminSession session;

  @override
  List<Object?> get props => <Object?>[session];
}
