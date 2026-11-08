import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/widgets/reward_card.dart';

class LoyaltyRewardsPage extends StatelessWidget {
  const LoyaltyRewardsPage({super.key, required this.onRedeem});

  final ValueChanged<RewardModel> onRedeem;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: BlocBuilder<LoyaltyCubit, LoyaltyState>(
      builder: (context, state) {
        final rewards = state.rewards;
        final available = rewards
            .where((reward) => reward.affordable(state.balance))
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(S.loyaltyRedeemableProducts),
            actions: [
              IconButton(
                tooltip: S.loyaltyRefreshCatalog,
                onPressed: state.isLoading
                    ? null
                    : () => context.read<LoyaltyCubit>().load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
            bottom: TabBar(
              tabs: [
                Tab(text: '${S.yourPointsUnlock} (${available.length})'),
                Tab(text: '${S.loyaltyRedeemableProducts} (${rewards.length})'),
              ],
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColor.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.gift, color: AppColor.primaryColor),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        S.loyaltyCatalogPointsBalance(state.balance),
                        style: AppFonts.medium14(context),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _RewardList(
                      rewards: available,
                      balance: state.balance,
                      isRedeeming: state.isRedeeming,
                      emptyText: S.loyaltyNoAvailableRewards,
                      onRedeem: onRedeem,
                    ),
                    _RewardList(
                      rewards: rewards,
                      balance: state.balance,
                      isRedeeming: state.isRedeeming,
                      emptyText: S.loyaltyNoAvailableRewards,
                      onRedeem: onRedeem,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RewardList extends StatelessWidget {
  const _RewardList({
    required this.rewards,
    required this.balance,
    required this.isRedeeming,
    required this.emptyText,
    required this.onRedeem,
  });

  final List<RewardModel> rewards;
  final int balance;
  final bool isRedeeming;
  final String emptyText;
  final ValueChanged<RewardModel> onRedeem;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: context.read<LoyaltyCubit>().load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppLayout.pageBody,
        children: [
          if (rewards.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: Text(emptyText)),
            ),
          for (final reward in rewards)
            RewardCard(
              reward: reward,
              locked: !reward.affordable(balance),
              busy: isRedeeming,
              onRedeem: reward.affordable(balance)
                  ? () => onRedeem(reward)
                  : null,
            ),
        ],
      ),
    );
  }
}
