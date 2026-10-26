import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_member_bits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class LoyaltyMemberTable extends StatelessWidget {
  const LoyaltyMemberTable({super.key, required this.members});

  final List<AdminLoyaltyMember> members;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, 960), 1600)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const _Header(),
                for (final member in members) _Row(member: member),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: _cell(theme, S.loyaltyMemberColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyBalanceColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyLifetimeColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyTierColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyRedemptionsColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyLastActivityColumn)),
        ],
      ),
    );
  }

  Widget _cell(ThemeData theme, String label) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.member});

  final AdminLoyaltyMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = adminBodyColor(theme);
    final muted = adminMutedColor(theme);
    final contact = member.contactLine;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                LoyaltyMemberAvatar(member: member),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: body,
                          fontSize: AppFontSizes.size11,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                      if (contact != null)
                        Text(
                          contact,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminSubtleColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _PointsCell(points: member.pointsBalance)),
          Expanded(
            flex: 2,
            child: Text(
              loyaltyCount(member.lifetimePoints),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LoyaltyTierBadge(tier: member.tier),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              loyaltyCount(member.redemptionsCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: body,
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              loyaltyLastActivity(member.lastActivityAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsCell extends StatelessWidget {
  const _PointsCell({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = points > 0;
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedStar,
          size: 14,
          color: active ? AppColor.adminAccent : adminMutedColor(theme),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            loyaltyCount(points),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? adminBodyColor(theme) : adminMutedColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
      ],
    );
  }
}
