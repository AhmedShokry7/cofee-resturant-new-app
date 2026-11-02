import 'package:flutter/foundation.dart';

import 'package:new_coffee/features/auth/data/model/auth_user.dart';

@immutable
sealed class EmailAuthState {
  const EmailAuthState();
}

final class EmailAuthInitial extends EmailAuthState {
  const EmailAuthInitial();
}

final class EmailAuthLoading extends EmailAuthState {
  const EmailAuthLoading();
}

final class EmailAuthCodeSent extends EmailAuthState {
  const EmailAuthCodeSent();
}

final class EmailAuthSuccess extends EmailAuthState {
  const EmailAuthSuccess(this.user);

  final AuthUser user;
}

final class EmailAuthFailure extends EmailAuthState {
  const EmailAuthFailure(this.message);

  final String message;
}
