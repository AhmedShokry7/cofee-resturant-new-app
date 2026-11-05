import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/features/auth/data/model/auth_exception.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_state.dart';

/// Signing in with a code the customer reads out of their mailbox.
///
/// A door of its own, next to the phone number and Google: the address is the
/// credential and the mail is the proof of it. Nothing here touches the SMS
/// path, so a customer whose number cannot be reached still gets in, and a
/// mailbox the server cannot write to still leaves the other two open.
class EmailAuthCubit extends Cubit<EmailAuthState> {
  EmailAuthCubit(this._repository, {this.session = const SessionRepository()})
    : super(const EmailAuthInitial());

  final AuthRepository _repository;

  /// The markers that decide where the next launch starts.
  final SessionRepository session;

  Future<void> sendCode({required String email}) async {
    if (state is EmailAuthLoading) return;
    emit(const EmailAuthLoading());
    try {
      await _repository.sendEmailCode(email: email);
      if (isClosed) return;
      emit(const EmailAuthCodeSent());
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      if (isClosed) return;
      emit(EmailAuthFailure(AuthCubit.reasonFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected email auth error: $error\n$stackTrace');
      if (isClosed) return;
      emit(const EmailAuthFailure(AppCopy.authUnexpected));
    }
  }

  Future<void> verifyCode({required String email, required String code}) async {
    if (state is EmailAuthLoading) return;
    emit(const EmailAuthLoading());
    try {
      final user = await _repository.verifyEmailCode(email: email, code: code);
      // Same rule as the phone flow: the marker is written and confirmed here,
      // so the screen only has to decide where in the stack to land. A marker
      // that will not land is reported, not acted on — the customer is verified
      // either way.
      final saved = await session.markAuthenticatedConfirmed();
      if (!saved) {
        debugPrint('[Auth] session marker could not be persisted.');
      }
      if (isClosed) return;
      emit(EmailAuthSuccess(user));
    } on AuthException catch (error) {
      debugPrint('AuthException: ${error.message}');
      if (isClosed) return;
      emit(EmailAuthFailure(AuthCubit.reasonFor(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected email auth error: $error\n$stackTrace');
      if (isClosed) return;
      emit(const EmailAuthFailure(AppCopy.authUnexpected));
    }
  }

  void reset() {
    if (isClosed) return;
    emit(const EmailAuthInitial());
  }
}
