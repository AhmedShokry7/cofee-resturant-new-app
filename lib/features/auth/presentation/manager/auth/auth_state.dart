part of 'auth_cubit.dart';

@immutable
sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSuccess extends AuthState {
  const AuthSuccess(this.user);

  final AuthUser user;
}

/// The address the customer just registered still has to confirm its email.
///
/// A separate state, because this is not a signed-in customer: the app keeps
/// them on the sign-up screen and writes no session marker.
final class AuthEmailConfirmationRequired extends AuthState {
  const AuthEmailConfirmationRequired();
}

/// The customer chose to browse without an account.
final class AuthSkipped extends AuthState {
  const AuthSkipped();
}

/// The provider released the session and the stored route was reset.
final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;
}
