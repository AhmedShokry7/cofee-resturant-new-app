import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_target_option.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';

enum AdminLoyaltyStatus { initial, loading, ready, failure }

class AdminLoyaltyState {
  const AdminLoyaltyState({
    this.status = AdminLoyaltyStatus.initial,
    this.overview = AdminLoyaltyOverview.empty,
    this.rewards = const <AdminLoyaltyReward>[],
    this.members = const <AdminLoyaltyMember>[],
    this.transactions = const <AdminLoyaltyTransaction>[],
    this.transactionsTotal = 0,
    this.targets = const <AdminLoyaltyTargetOption>[],
    this.targetsLoading = false,
    this.targetsError,
    this.errorMessage,
  });

  final AdminLoyaltyStatus status;
  final AdminLoyaltyOverview overview;
  final List<AdminLoyaltyReward> rewards;
  final List<AdminLoyaltyMember> members;
  final List<AdminLoyaltyTransaction> transactions;
  final int transactionsTotal;
  final List<AdminLoyaltyTargetOption> targets;
  final bool targetsLoading;
  final String? targetsError;
  final String? errorMessage;

  bool get isLoading => status == AdminLoyaltyStatus.loading;
  bool get isFailure => status == AdminLoyaltyStatus.failure;

  bool get hasData =>
      overview.hasRule ||
      rewards.isNotEmpty ||
      members.isNotEmpty ||
      transactions.isNotEmpty;

  AdminLoyaltyState copyWith({
    AdminLoyaltyStatus? status,
    AdminLoyaltyOverview? overview,
    List<AdminLoyaltyReward>? rewards,
    List<AdminLoyaltyMember>? members,
    List<AdminLoyaltyTransaction>? transactions,
    int? transactionsTotal,
    List<AdminLoyaltyTargetOption>? targets,
    bool? targetsLoading,
    String? targetsError,
    String? errorMessage,
    bool clearError = false,
    bool clearTargetsError = false,
  }) {
    return AdminLoyaltyState(
      status: status ?? this.status,
      overview: overview ?? this.overview,
      rewards: rewards ?? this.rewards,
      members: members ?? this.members,
      transactions: transactions ?? this.transactions,
      transactionsTotal: transactionsTotal ?? this.transactionsTotal,
      targets: targets ?? this.targets,
      targetsLoading: targetsLoading ?? this.targetsLoading,
      targetsError: clearTargetsError
          ? null
          : (targetsError ?? this.targetsError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
