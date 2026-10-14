import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/loyalty/data/rewards_list.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/widgets/reward_card.dart';

class LoyaltyPage extends StatelessWidget {
  const LoyaltyPage({super.key});

  static const routeName = "loyaltyRoute";

  void _redeem(BuildContext context, RewardModel reward) {
    final redeemed = context.read<LoyaltyCubit>().redeem(reward);
    if (!context.mounted) return;
    if (redeemed) {
      context.read<CartCubit>().add(
        reward.product,
        unitPrice: 0,
        note: 'Loyalty reward',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enjoy your ${reward.product.name}!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not enough points yet")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = getRewardsList();
    return Scaffold(
      appBar: AppBar(title: const Text("Loyalty Points")),
      body: BlocBuilder<LoyaltyCubit, LoyaltyState>(
        builder: (context, state) {
          final unlocked = rewards
              .where((reward) => reward.affordable(state.balance))
              .toList();
          final locked = rewards
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
              _BalanceCard(balance: state.balance),
              SizedBox(height: SpacingTokens.xl.h),
              Text(
                unlocked.isEmpty
                    ? "Keep collecting to unlock rewards"
                    : "Your points unlock",
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
                Text(
                  "Keep collecting",
                  style: AppFonts.semiBold18(context),
                ),
                SizedBox(height: SpacingTokens.md.h),
                for (final reward in locked)
                  RewardCard(reward: reward, locked: true),
              ],
              if (state.transactions.isNotEmpty) ...[
                SizedBox(height: SpacingTokens.md.h),
                Text("History", style: AppFonts.semiBold18(context)),
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
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

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
            "Your Balance",
            style: AppFonts.regular14(
              context,
            ).copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$balance',
                style: AppFonts.semiBold32(
                  context,
                ).copyWith(color: AppColor.whiteColor),
              ),
              SizedBox(width: SpacingTokens.xs.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  "points",
                  style: AppFonts.medium16(
                    context,
                  ).copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
          SizedBox(height: SpacingTokens.xs.h),
          Text(
            "Earn 1 point per 1 EGP on every order",
            style: AppFonts.regular12(
              context,
            ).copyWith(color: AppColor.whiteColor.withValues(alpha: 0.85)),
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
          Expanded(
            child: Text(title, style: AppFonts.medium14(context)),
          ),
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
