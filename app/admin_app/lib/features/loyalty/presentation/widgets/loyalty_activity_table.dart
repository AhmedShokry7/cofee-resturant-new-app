import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/initials.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/features/loyalty/data/models/admin_loyalty_transaction.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class LoyaltyActivityTable extends StatelessWidget {
  const LoyaltyActivityTable({super.key, required this.transactions});

  final List<AdminLoyaltyTransaction> transactions;

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
                for (final transaction in transactions)
                  _Row(transaction: transaction),
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
          Expanded(flex: 4, child: _cell(theme, S.loyaltyMemberColumn)),
          Expanded(flex: 4, child: _cell(theme, S.loyaltyMovementColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyPointsColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyBalanceAfterColumn)),
          Expanded(flex: 2, child: _cell(theme, S.loyaltyDateColumn)),
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
  const _Row({required this.transaction});

  final AdminLoyaltyTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = transaction.displayName(AppLocale.instance.language);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                AdminAvatarImage(
                  size: 27,
                  borderRadius: BorderRadius.circular(8),
                  fallbackText: initialsOf(name),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loyaltyReasonLabel(transaction.reason),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                Text(
                  loyaltyReference(transaction),
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
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LoyaltyPointsDelta(points: transaction.points),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              loyaltyCount(transaction.balanceAfter),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              transaction.createdAt == null
                  ? S.loyaltyNoReference
                  : localizedDateTime(transaction.createdAt!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
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

class LoyaltyPointsDelta extends StatelessWidget {
  const LoyaltyPointsDelta({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earning = points >= 0;
    final accent = earning ? AppColor.trendPositive : AppColor.adminWarning;
    final foreground = adminFlagForeground(theme, accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          accent,
          earning
              ? AppColor.trendPositiveSurface
              : AppColor.adminWarningSurface,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        loyaltySignedPoints(points),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: AppFontSizes.size9_5,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_5,
        ),
      ),
    );
  }
}
