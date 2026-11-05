part of 'password_reset_cubit.dart';

@immutable
sealed class PasswordResetState {}

final class PasswordResetInitial extends PasswordResetState {}

final class PasswordResetLoading extends PasswordResetState {}

final class PasswordResetEmailSent extends PasswordResetState {}

final class PasswordResetSuccess extends PasswordResetState {}

final class PasswordResetFailure extends PasswordResetState {
  /// Why the attempt failed, held as a token so the screen reads the sentence
  /// in the language the customer is using now.
  final AppCopy reason;

  String get message => reason.copy;

  PasswordResetFailure(this.reason);
}
