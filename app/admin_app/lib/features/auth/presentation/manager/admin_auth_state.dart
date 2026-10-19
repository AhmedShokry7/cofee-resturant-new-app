import 'package:admin_app/features/auth/data/models/admin_session.dart';

enum AdminAuthStatus { checking, unauthenticated, authenticated }

class AdminAuthState {
  const AdminAuthState({
    required this.status,
    this.session,
    this.errorMessage,
    this.isSubmitting = false,
  });

  final AdminAuthStatus status;
  final AdminSession? session;
  final String? errorMessage;
  final bool isSubmitting;

  AdminAuthState copyWith({
    AdminAuthStatus? status,
    AdminSession? session,
    String? errorMessage,
    bool clearError = false,
    bool? isSubmitting,
  }) {
    return AdminAuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}
