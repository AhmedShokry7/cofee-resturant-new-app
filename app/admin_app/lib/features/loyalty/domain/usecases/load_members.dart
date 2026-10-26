import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// قراءة أعضاء برنامج الولاء.
class LoadMembersUseCase {
  const LoadMembersUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<List<AdminLoyaltyMember>> call() => _repository.loadMembers();
}
