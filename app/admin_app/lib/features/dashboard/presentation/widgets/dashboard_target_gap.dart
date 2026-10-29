import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// الفرجة تحت شريط الهدف: ما بقي لبلوغه، أو الخبر أنه بُلِغ.
///
/// النسبة في الحلقة تقول «كم أنجزت»، وهذا السطر يقول «كم بقي» — رقمان لا يكرر
/// أحدهما الآخر، والثاني هو الذي يحرّك الأدمن: «٦٠٪» لا تخبره أيشتغل أم ينتظر.
class DashboardTargetGap extends StatelessWidget {
  const DashboardTargetGap({
    super.key,
    required this.reached,
    required this.remaining,
  });

  final bool reached;

  /// ما نقص عن الهدف، وقد يكون سالبًا حين زاد المُحقَّق عنه.
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.px10,
        vertical: AppSizes.px6,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          AppIcon(
            reached ? AppIcons.checkmarkCircle02 : AppIcons.percent,
            size: AppSizes.px16,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    reached
                        ? S.dashboardTargetReached
                        : S.dashboardRemainingToTarget,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
                if (!reached) ...[
                  const Spacer(),
                  const SizedBox(width: AppSizes.px6),
                  Text(
                    localizeDigits(formatAmount(remaining)),
                    maxLines: 1,
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size9_5,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  const CurrencyIcon(size: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
