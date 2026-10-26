import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_reward.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_rule.dart';
import 'package:admin_app/features/loyalty/data/repositories/admin_loyalty_repository.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_cubit.dart';
import 'package:admin_app/features/loyalty/presentation/manager/admin_loyalty_state.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_directory.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_page_body.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_reward_dialog.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_rule_dialog.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({
    super.key,
    required this.searchController,
    this.canManage = false,
    this.cubit,
  });

  static const String routeName = '/loyalty';

  final AdminSearchController searchController;
  final bool canManage;
  final AdminLoyaltyCubit? cubit;

  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage> {
  late final AdminLoyaltyCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';
  final Set<String> _pendingRewards = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminLoyaltyCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  Future<void> _openRewardDialog([AdminLoyaltyReward? reward]) {
    return showLoyaltyRewardDialog(
      context: context,
      cubit: _cubit,
      reward: reward,
    );
  }

  Future<void> _openRuleDialog(AdminLoyaltyRule? rule) {
    return showLoyaltyRuleDialog(context: context, cubit: _cubit, rule: rule);
  }

  Future<void> _toggleReward(AdminLoyaltyReward reward) async {
    if (_pendingRewards.contains(reward.id)) return;
    _pendingRewards.add(reward.id);
    try {
      final outcome = await _cubit.setRewardActive(reward.id, !reward.isActive);
      if (!mounted) return;
      final message = switch (outcome) {
        LoyaltyRewardMutationOutcome.success =>
          reward.isActive
              ? S.loyaltyRewardPausedSuccess
              : S.loyaltyRewardActivated,
        LoyaltyRewardMutationOutcome.targetUnavailable =>
          S.loyaltyRewardTargetUnavailableCannotActivate,
        LoyaltyRewardMutationOutcome.notFound => S.loyaltyRewardNotFound,
        _ => S.loyaltyRewardActionFailed,
      };
      _showMessage(
        message,
        error: outcome != LoyaltyRewardMutationOutcome.success,
      );
    } finally {
      _pendingRewards.remove(reward.id);
    }
  }

  Future<void> _deleteReward(AdminLoyaltyReward reward) async {
    if (_pendingRewards.contains(reward.id)) return;
    final confirmed = await _confirmDelete(reward);
    if (confirmed != true || !mounted) return;
    _pendingRewards.add(reward.id);
    try {
      final outcome = await _cubit.deleteReward(reward.id);
      if (!mounted) return;
      final message = switch (outcome) {
        LoyaltyRewardMutationOutcome.success => S.loyaltyRewardDeleted,
        LoyaltyRewardMutationOutcome.hasRedemptions =>
          S.loyaltyRewardDeleteHasRedemptions,
        LoyaltyRewardMutationOutcome.notFound => S.loyaltyRewardNotFound,
        _ => S.loyaltyRewardActionFailed,
      };
      _showMessage(
        message,
        error: outcome != LoyaltyRewardMutationOutcome.success,
      );
    } finally {
      _pendingRewards.remove(reward.id);
    }
  }

  Future<bool?> _confirmDelete(AdminLoyaltyReward reward) {
    final blocked = reward.wasRedeemed;
    final name = loyaltyRewardTargetName(reward);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            S.loyaltyRewardDeleteTitle,
            style: TextStyle(
              fontSize: AppFontSizes.size15,
              fontWeight: AppFontWeights.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            blocked
                ? S.loyaltyRewardDeleteHasRedemptions
                : S.loyaltyRewardDeleteMessage(name),
            style: const TextStyle(
              fontSize: AppFontSizes.size11_5,
              height: AppTextHeights.line1_6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(blocked ? S.loyaltyRewardDeleteKeep : S.cancel),
            ),
            if (!blocked)
              FilledButton(
                key: const Key('loyalty-reward-delete-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColor.errorColor,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Text(
                  S.loyaltyRewardDeleteConfirm,
                  style: const TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminLoyaltyCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminLoyaltyCubit, AdminLoyaltyState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return LoyaltyPageBody(
            overview: state.overview,
            canManage: widget.canManage,
            onAdd: _openRewardDialog,
            onEditRule: () => _openRuleDialog(state.overview.rule),
            errorMessage: state.isFailure ? state.errorMessage : null,
            onRefresh: _cubit.load,
            directory: LoyaltyDirectory(
              rewards: state.rewards,
              members: state.members,
              transactions: state.transactions,
              transactionsTotal: state.transactionsTotal,
              search: _searchQuery,
              onSearchChanged: widget.searchController.update,
              canManage: widget.canManage,
              onAdd: _openRewardDialog,
              onEdit: _openRewardDialog,
              onToggle: _toggleReward,
              onDelete: _deleteReward,
            ),
          );
        },
      ),
    );
  }
}
