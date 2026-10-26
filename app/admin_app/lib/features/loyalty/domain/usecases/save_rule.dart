import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/domain/repositories/loyalty_repository.dart';

/// حفظ قاعدة الولاء بعد فحص القاعدة.
class SaveRuleUseCase {
  const SaveRuleUseCase(this._repository);

  final LoyaltyRepository _repository;

  Future<LoyaltyRuleSaveOutcome> call(AdminLoyaltyRuleDraft draft) =>
      _repository.saveRule(draft);
}
