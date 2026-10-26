import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// قراءة أهداف المكافآت القابلة للاختيار.
class LoadTargetOptionsUseCase {
  const LoadTargetOptionsUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<List<AdminLoyaltyTargetOption>> call() =>
      _repository.loadTargetOptions();
}
