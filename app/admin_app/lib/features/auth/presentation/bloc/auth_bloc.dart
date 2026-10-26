import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/usecase/use_case.dart';
import 'package:admin_app/features/auth/domain/usecases/check_session.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_in.dart';
import 'package:admin_app/features/auth/domain/usecases/sign_out.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_state.dart';

/// يدير دورة حياة جلسة الموظف: الفحص، الدخول، والخروج.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required CheckSessionUseCase checkSessionUseCase,
    required SignInUseCase signInUseCase,
    required SignOutUseCase signOutUseCase,
  }) : _checkSession = checkSessionUseCase,
       _signIn = signInUseCase,
       _signOut = signOutUseCase,
       super(const AuthChecking()) {
    on<AuthSessionCheckRequested>(_onSessionCheckRequested);
    on<AuthSignInSubmitted>(_onSignInSubmitted);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
  }

  final CheckSessionUseCase _checkSession;
  final SignInUseCase _signIn;
  final SignOutUseCase _signOut;

  Future<void> _onSessionCheckRequested(
    AuthSessionCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    // الحالة الابتدائية هي نفسها حالة الفحص، فلا داعي لإعادة إرسالها.
    if (state is! AuthChecking) emit(const AuthChecking());
    final result = await _checkSession(const NoParams());
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(AuthSignedOut(failure: failure)),
      (session) => session == null
          ? emit(const AuthSignedOut())
          : emit(AuthSignedIn(session)),
    );
  }

  Future<void> _onSignInSubmitted(
    AuthSignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final current = state;
    final signedOut = current is AuthSignedOut
        ? current
        : const AuthSignedOut();
    emit(signedOut.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _signIn(
      SignInParams(email: event.email, password: event.password),
    );
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(signedOut.copyWith(failure: failure)),
      (session) => emit(AuthSignedIn(session)),
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _signOut();
    } catch (_) {
      // فشل الإنهاء عن بُعد لا يمنع مسح الجلسة من الواجهة.
    }
    if (emit.isDone) return;
    emit(const AuthSignedOut());
  }

  void _onPasswordVisibilityToggled(
    AuthPasswordVisibilityToggled event,
    Emitter<AuthState> emit,
  ) {
    final current = state;
    if (current is AuthSignedOut) {
      emit(current.copyWith(obscurePassword: !current.obscurePassword));
    }
  }
}
