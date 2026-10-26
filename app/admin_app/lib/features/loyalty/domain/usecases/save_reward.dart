import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// حفظ مكافأة ولاء بعد فحص القاعدة.
class SaveRewardUseCase {
  const SaveRewardUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<LoyaltyRewardSaveOutcome> call(AdminLoyaltyRewardDraft draft) =>
      _repository.saveReward(draft);
}
