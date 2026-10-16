import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/loyalty/data/model/reward_model.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/widgets/reward_card.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class LoyaltyPage extends StatelessWidget {
  const LoyaltyPage({super.key});

  static const routeName = "loyaltyRoute";

  Future<void> _redeem(BuildContext context, RewardModel reward) async {
    final loyalty = context.read<LoyaltyCubit>();
    final wasGuest = loyalty.state.isGuest;
    final redeemed = await loyalty.redeem(reward);
    if (!context.mounted) return;
    if (redeemed) {
      // Server redemption already places the reward in the server cart.
      // Guests still use the device cart because they have no server cart.
      if (wasGuest) {
        context.read<CartCubit>().add(
          reward.product,
          unitPrice: 0,
          note: S.loyaltyRewardNote,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.enjoyReward(reward.product.name))),
      );
    } else {
      final error = context.read<LoyaltyCubit>().state.error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error ?? S.notEnoughPoints)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.loyaltyPoints)),
      body: BlocBuilder<LoyaltyCubit, LoyaltyState>(
        builder: (context, state) {
          if (state.isLoading && state.rewards.isEmpty) {
            return const LoyaltyLoadingView();
          }
          final unlocked = state.rewards
              .where((reward) => reward.affordable(state.balance))
              .toList();
          final locked = state.rewards
              .where((reward) => !reward.affordable(state.balance))
              .toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            children: [
              _BalanceCard(
                balance: state.balance,
                earnText: _earnText(state),
                accountText: state.isGuest
                    ? S.guestWalletDevice
                    : S.lifetimePoints(state.tier, state.lifetimePoints),
              ),
              SizedBox(height: SpacingTokens.xl.h),
              Text(
                unlocked.isEmpty
                    ? S.keepCollectingToUnlock
                    : S.yourPointsUnlock,
                style: AppFonts.semiBold18(context),
              ),
              SizedBox(height: SpacingTokens.md.h),
              for (final reward in unlocked)
                RewardCard(
                  reward: reward,
                  locked: false,
                  onRedeem: () => _redeem(context, reward),
                ),
              if (locked.isNotEmpty) ...[
                SizedBox(height: SpacingTokens.md.h),
                Text(S.keepCollecting, style: AppFonts.semiBold18(context)),
                SizedBox(height: SpacingTokens.md.h),
                for (final reward in locked)
                  RewardCard(reward: reward, locked: true),
              ],
              if (state.transactions.isNotEmpty) ...[
                SizedBox(height: SpacingTokens.md.h),
                Text(S.history, style: AppFonts.semiBold18(context)),
                SizedBox(height: SpacingTokens.md.h),
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
      padding: EdgeInsets.all(SpacingTokens.xl.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.yourBalance,
            style: AppFonts.regular14(context)
                .copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$balance',
                style: AppFonts.semiBold32(context)
                    .copyWith(color: AppColor.whiteColor),
              ),
              SizedBox(width: SpacingTokens.xs.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  S.pointsWord,
                  style: AppFonts.medium16(context).copyWith(
                    color: AppColor.whiteColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Text(
            earnText,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
          ),
          SizedBox(height: SpacingTokens.xs.h),
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
      margin: EdgeInsets.only(bottom: SpacingTokens.sm.h),
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.md.w,
        vertical: SpacingTokens.sm.h,
      ),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
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
