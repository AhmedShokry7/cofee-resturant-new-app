import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_channel_slice.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// سطر مفتاح واحدة: لونها واسمها وعدد طلباتها ومالها.
///
/// الأسماء تخرج من `fulfillmentLabel` نفسها التي تسمّي الطلب في شاشة الطلبات
/// والمطبخ، فلا يختلف اسم القناة بين شاشة وأخرى حين تُترجم.
class DashboardChannelLegendRow extends StatelessWidget {
  const DashboardChannelLegendRow({
    super.key,
    required this.slice,
    required this.color,
    required this.share,
    required this.channelLabel,
  });

  final AdminDashboardChannelSlice slice;
  final Color color;

  /// نسبة القناة من طلبات المدى، محسوبة في Domain لا هنا.
  final double share;
  final String channelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.px6),
      child: Row(
        children: [
          Container(
            width: AppSizes.px10,
            height: AppSizes.px10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Text(
              channelLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.medium,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Text(
            formatPercent(share * 100),
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Text(
            localizeDigits('${slice.orders}'),
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size10_5,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Text(
            formatMoneyWithCurrency(slice.revenue),
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size10_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}
