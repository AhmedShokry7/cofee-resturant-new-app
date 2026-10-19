import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/features/auth/data/repositories/admin_auth_repository.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_state.dart';

class AdminAuthCubit extends Cubit<AdminAuthState> {
  AdminAuthCubit({AdminAuthRepository? repository})
      : _repository = repository ?? AdminAuthRepository(),
        super(const AdminAuthState(status: AdminAuthStatus.checking));

  final AdminAuthRepository _repository;

  Future<void> checkSession() async {
    emit(const AdminAuthState(status: AdminAuthStatus.checking));
    try {
      final session = await _repository.restoreSession();
      if (session == null) {
        emit(const AdminAuthState(status: AdminAuthStatus.unauthenticated));
      } else {
        emit(AdminAuthState(
          status: AdminAuthStatus.authenticated,
          session: session,
        ));
      }
    } catch (error) {
      emit(AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: _messageFor(error),
      ));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final session = await _repository.signIn(email: email, password: password);
      emit(AdminAuthState(
        status: AdminAuthStatus.authenticated,
        session: session,
      ));
    } catch (error) {
      emit(AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        errorMessage: _messageFor(error),
      ));
    }
  }

  Future<void> signOut() async {
    try {
      await _repository.signOut();
    } finally {
      emit(const AdminAuthState(status: AdminAuthStatus.unauthenticated));
    }
  }

  String _messageFor(Object error) {
    if (error is AdminAuthException) return error.message;
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('not an active staff') ||
          message.contains('staff record not found') ||
          message.contains('not authenticated')) {
        return 'This account is not an active staff member.';
      }
      return error.message;
    }
    if (error is StateError) {
      return 'Supabase is not configured. Check the admin app configuration.';
    }
    return 'Unable to sign in. Please try again.';
  }
}
