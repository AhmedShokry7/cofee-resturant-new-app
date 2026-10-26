import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_member.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_member_bits.dart';
import 'package:admin_app/shared/widgets/admin_labeled_value.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class LoyaltyMemberCards extends StatelessWidget {
  const LoyaltyMemberCards({super.key, required this.members});

  final List<AdminLoyaltyMember> members;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: members.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
    itemBuilder: (context, index) => _MemberCard(member: members[index]),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final AdminLoyaltyMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.lg);
    final contact = member.contactLine;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LoyaltyMemberAvatar(member: member, size: 38),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size12,
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
                          fontSize: AppFontSizes.size10,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px8),
              LoyaltyTierBadge(tier: member.tier),
            ],
          ),
          const SizedBox(height: AppSizes.px10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AdminLabeledValue(
                  label: S.loyaltyBalanceColumn,
                  child: Text(
                    loyaltyCount(member.pointsBalance),
                    style: TextStyle(
                      color: member.hasPoints
                          ? adminBodyColor(theme)
                          : adminMutedColor(theme),
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AdminLabeledValue(
                  label: S.loyaltyLifetimeColumn,
                  child: Text(
                    loyaltyCount(member.lifetimePoints),
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AdminLabeledValue(
                  label: S.loyaltyRedemptionsColumn,
                  child: Text(
                    loyaltyCount(member.redemptionsCount),
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          Row(
            children: [
              AppIcon(
                AppIcons.clock01,
                size: 13,
                color: adminMutedColor(theme),
              ),
              const SizedBox(width: AppSizes.px6),
              Text(
                '${S.loyaltyLastActivityColumn}: ',
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size9_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
              Expanded(
                child: Text(
                  loyaltyLastActivity(member.lastActivityAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
