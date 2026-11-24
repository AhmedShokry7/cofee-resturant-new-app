import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// يتحقق من كود تأكيد البريد ثم يسلم الرمز للقاعدة لتقرر تحويل الحساب لموظف.
class ConfirmEmailAndAcceptInvitationUseCase {
  const ConfirmEmailAndAcceptInvitationUseCase(this._repository);

  final AuthRepository _repository;

  Future<InvitationAcceptOutcome> call({
    required String token,
    required String email,
    required String password,
    required String confirmationCode,
  }) => _repository.confirmEmailAndAccept(
    token: token,
    email: email,
    password: password,
    confirmationCode: confirmationCode,
  );
}
