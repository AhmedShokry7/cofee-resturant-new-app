import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// فتح حساب المدعو ثم تسليم الرمز للقاعدة لتقرر وحدها بقائه موظفًا.
class AcceptInvitationUseCase {
  const AcceptInvitationUseCase(this._repository);

  final AuthRepository _repository;

  Future<InvitationAcceptOutcome> call({
    required String token,
    required String email,
    required String password,
  }) => _repository.acceptInvitation(
    token: token,
    email: email,
    password: password,
  );
}
