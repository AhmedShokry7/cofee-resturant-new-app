import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// قراءة ما يعد به رمز الدعوة قبل إنشاء أي حساب.
class LookupInvitationUseCase {
  const LookupInvitationUseCase(this._repository);

  final AuthRepository _repository;

  Future<InvitationLookup> call(String token) =>
      _repository.lookupInvitation(token);
}
