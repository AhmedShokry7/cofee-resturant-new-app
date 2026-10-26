import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_reward_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_rule_draft.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_transaction.dart';

/// نتيجة حفظ قاعدة الولاء كما تعيدها القاعدة.
enum LoyaltyRuleSaveOutcome {
  saved,
  invalidRate,
  invalidValue,
  notFound,
  failed,
}

/// نتيجة حفظ مكافأة ولاء كما تعيدها القاعدة.
enum LoyaltyRewardSaveOutcome {
  saved,
  duplicateTarget,
  invalidTarget,
  invalidType,
  targetUnavailable,
  invalidPoints,
  invalidStock,
  notFound,
  failed,
}

/// نتيجة تعديل مكافأة ولاء (تنشيط أو حذف) كما تعيدها القاعدة.
enum LoyaltyRewardMutationOutcome {
  success,
  notFound,
  hasRedemptions,
  targetUnavailable,
  failed,
}

/// عقد قراءة ملخص الولاء والمكافآت والأعضاء والحركات وكتابة المكافآت والقواعد.
///
/// التنفيذ الفعلي (Supabase) في `data/repositories`، فلا يعرف المجال شيئًا عن
/// الشبكة؛ الأخطاء تبقى استثناءات تعالجها الطبقة العليا كما تفعل اليوم.
abstract interface class LoyaltyRepository {
  /// يقرأ ملخص برنامج الولاء.
  Future<AdminLoyaltyOverview> loadOverview();

  /// يقرأ كل مكافآت الولاء.
  Future<List<AdminLoyaltyReward>> loadRewards();

  /// يقرأ أهداف المكافآت القابلة للاختيار.
  Future<List<AdminLoyaltyTargetOption>> loadTargetOptions();

  /// يقرأ أعضاء الولاء.
  Future<List<AdminLoyaltyMember>> loadMembers();

  /// يقرأ صفحة من حركات الولاء.
  Future<AdminLoyaltyTransactionFeed> loadTransactions({int limit = 300});

  /// يحفظ قاعدة الولاء ويعيد نتيجة العملية.
  Future<LoyaltyRuleSaveOutcome> saveRule(AdminLoyaltyRuleDraft draft);

  /// يحفظ مكافأة ويعيد نتيجة العملية.
  Future<LoyaltyRewardSaveOutcome> saveReward(AdminLoyaltyRewardDraft draft);

  /// ينشط المكافأة أو يوقفها ويعيد نتيجة العملية.
  Future<LoyaltyRewardMutationOutcome> setRewardActive(
    String rewardId,
    bool active,
  );

  /// يحذف المكافأة ويعيد نتيجة العملية.
  Future<LoyaltyRewardMutationOutcome> deleteReward(String rewardId);
}
