import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/widgets/reward_card.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class LoyaltyPage extends StatelessWidget {
  const LoyaltyPage({super.key});

  static const routeName = "loyaltyRoute";

  Future<void> _redeem(BuildContext context, RewardModel reward) async {
    final loyalty = context.read<LoyaltyCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final wasGuest = loyalty.state.isGuest;
    // Read before the wait, and only for the path that uses it: a guest spend
    // puts the product in the device cart, while a signed-in spend is fulfilled
    // by the server and needs no cart at all.
    final cart = wasGuest ? context.read<CartCubit>() : null;
    final outcome = await loyalty.redeem(reward);
    // The tap that is still in flight answers this reward with its own
    // message, so a second one says nothing rather than repeating it.
    if (outcome == RedeemOutcome.inProgress) return;

    if (outcome == RedeemOutcome.redeemed && wasGuest) {
      // Signed-in redemption is fulfilled by the server: a product or bundle
      // becomes a free pickup order and a plan starts a subscription. Guests
      // only have the device cart and can redeem product rewards.
      final product = reward.product;
      if (product != null) {
        cart?.add(product, unitPrice: 0, note: S.loyaltyRewardNote);
      }
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_redeemMessage(outcome, reward, wasGuest))),
    );
  }

  /// One sentence per outcome, in the customer's language.
  ///
  /// The backend's own words are never printed, and a failure of the network is
  /// never described as a shortage of points.
  static String _redeemMessage(
    RedeemOutcome outcome,
    RewardModel reward,
    bool wasGuest,
  ) => switch (outcome) {
    // Unreachable: the caller returns before building a message for it.
    RedeemOutcome.inProgress => '',
    RedeemOutcome.redeemed =>
      wasGuest ? S.enjoyReward(reward.name) : _successMessage(reward),
    RedeemOutcome.notEnoughPoints => S.notEnoughPoints,
    RedeemOutcome.needsBranch => S.selectBranchBeforeRedeeming,
    RedeemOutcome.requiresAccount => S.rewardRequiresAccount,
    RedeemOutcome.refused => S.couldNotRedeemReward,
  };

  static String _successMessage(RewardModel reward) => switch (reward.type) {
    RewardTargetType.plan => S.rewardSubscriptionActivated(reward.name),
    RewardTargetType.product ||
    RewardTargetType.bundle => S.rewardOrderCreated(reward.name),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.loyaltyPoints)),
      body: BlocListener<LoyaltyCubit, LoyaltyState>(
        // The rewards are public reference rows; when they arrived but the
        // wallet did not, the page has something to show and only the balance
        // needs a word of warning.
        listenWhen: (previous, current) =>
            current.error != null && current.error != previous.error,
        listener: (context, state) {
          if (state.rewards.isEmpty) return;
          // What the server said stays out of the sentence — the customer needs
          // to know the points on screen may be old, not which table refused.
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(S.couldNotRefreshWallet)));
        },
        child: BlocBuilder<LoyaltyCubit, LoyaltyState>(
          builder: (context, state) {
            if (state.isLoading && state.rewards.isEmpty) {
              return const LoyaltyLoadingView();
            }
            // A wallet the server would not answer is not a customer who has
            // no points: showing the empty reward list would tell them to keep
            // collecting when there is nothing to collect from.
            if (state.error != null && state.rewards.isEmpty) {
              return EmptyState(
                icon: AppIcons.gift,
                title: S.couldNotLoadLoyalty,
                actionLabel: S.retry,
                onAction: () => context.read<LoyaltyCubit>().load(),
              );
            }
            final unlocked = state.rewards
                .where((reward) => reward.affordable(state.balance))
                .toList();
            final locked = state.rewards
                .where((reward) => !reward.affordable(state.balance))
                .toList();
            return ListView(
              padding: AppLayout.pageBody,
              children: [
                _BalanceCard(
                  balance: state.balance,
                  earnText: _earnText(state),
                  accountText: state.isGuest
                      ? S.guestWalletDevice
                      : S.lifetimePoints(state.tierLabel, state.lifetimePoints),
                ),
                SizedBox(height: AppSpacing.xl),
                Text(
                  unlocked.isEmpty
                      ? S.keepCollectingToUnlock
                      : S.yourPointsUnlock,
                  style: AppFonts.semiBold18(context),
                ),
                SizedBox(height: AppSpacing.md),
                for (final reward in unlocked)
                  RewardCard(
                    reward: reward,
                    locked: false,
                    // One spend at a time: the reward that is being answered
                    // cannot be answered again.
                    busy: state.isRedeeming,
                    onRedeem: () => _redeem(context, reward),
                  ),
                if (locked.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.md),
                  Text(S.keepCollecting, style: AppFonts.semiBold18(context)),
                  SizedBox(height: AppSpacing.md),
                  for (final reward in locked)
                    RewardCard(reward: reward, locked: true),
                ],
                if (state.transactions.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.md),
                  Text(S.history, style: AppFonts.semiBold18(context)),
                  SizedBox(height: AppSpacing.md),
                  for (final transaction in state.transactions)
                    _HistoryTile(
                      title: transaction.title,
                      points: transaction.points,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _earnText(LoyaltyState state) {
    final rate = state.pointsPerCurrencyUnit;
    if (rate == null) return S.earnRateUnavailable;
    final formatted = rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toString();
    return S.earnRate(formatted, state.currencyCode);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.earnText,
    required this.accountText,
  });

  final int balance;
  final String earnText;
  final String accountText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        // Not const: the brand colours are read from the CMS at start-up, so a
        // const gradient would freeze the values the app shipped with.
        gradient: LinearGradient(
          colors: [AppColor.primaryColor, AppColor.primaryColorEnd],
        ),
        borderRadius: BorderRadius.circular(AppRadius.r20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.yourBalance,
            style: AppFonts.regular14(context)
                .copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
          ),
          SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$balance',
                style: AppFonts.semiBold32(context)
                    .copyWith(color: AppColor.whiteColor),
              ),
              SizedBox(width: AppSpacing.xs),
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  S.pointsWord,
                  style: AppFonts.medium16(context).copyWith(
                    color: AppColor.whiteColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            earnText,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            accountText,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.title, required this.points});

  final String title;
  final int points;

  @override
  Widget build(BuildContext context) {
    final earned = points >= 0;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppFonts.medium14(context))),
          Text(
            '${earned ? '+' : ''}$points',
            style: AppFonts.semiBold14(context).copyWith(
              color: earned ? AppColor.greenColor : AppColor.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
