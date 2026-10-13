part of 'password_reset_cubit.dart';

@immutable
sealed class PasswordResetState {}

final class PasswordResetInitial extends PasswordResetState {}

final class PasswordResetLoading extends PasswordResetState {}

final class PasswordResetEmailSent extends PasswordResetState {}

final class PasswordResetSuccess extends PasswordResetState {}

final class PasswordResetFailure extends PasswordResetState {
  final String message;
  PasswordResetFailure(this.message);
}
