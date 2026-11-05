import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/auth/data/model/auth_user.dart';

@immutable
sealed class PhoneAuthState {
  const PhoneAuthState();
}

final class PhoneAuthInitial extends PhoneAuthState {
  const PhoneAuthInitial();
}

final class PhoneAuthLoading extends PhoneAuthState {
  const PhoneAuthLoading();
}

final class PhoneAuthCodeSent extends PhoneAuthState {
  const PhoneAuthCodeSent();
}

final class PhoneAuthSuccess extends PhoneAuthState {
  const PhoneAuthSuccess(this.user);

  final AuthUser user;
}

final class PhoneAuthFailure extends PhoneAuthState {
  const PhoneAuthFailure(this.reason);

  /// Why the attempt failed, held as a token so the screen reads the sentence
  /// in the language the customer is using now.
  final AppCopy reason;

  String get message => reason.copy;
}
