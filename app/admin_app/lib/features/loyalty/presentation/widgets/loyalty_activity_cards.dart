import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_activity_table.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class LoyaltyActivityCards extends StatelessWidget {
  const LoyaltyActivityCards({super.key, required this.transactions});

  final List<AdminLoyaltyTransaction> transactions;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: transactions.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) =>
        _ActivityCard(transaction: transactions[index]),
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.transaction});

  final AdminLoyaltyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);
    final name = transaction.displayName(AppLocale.instance.language);
    final createdAt = transaction.createdAt;
    return Container(
      padding: const EdgeInsets.all(12),
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
              AdminAvatarImage(
                size: 34,
                borderRadius: BorderRadius.circular(10),
                fallbackText: initialsOf(name),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      loyaltyReasonLabel(transaction.reason),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LoyaltyPointsDelta(points: transaction.points),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedLink01,
                size: 13,
                color: adminMutedColor(theme),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  loyaltyReference(transaction),
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
          const SizedBox(height: 4),
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 13,
                color: adminMutedColor(theme),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  createdAt == null
                      ? S.loyaltyNoReference
                      : localizedDateTime(createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '${S.loyaltyBalanceAfterColumn}: ${loyaltyCount(transaction.balanceAfter)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
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
