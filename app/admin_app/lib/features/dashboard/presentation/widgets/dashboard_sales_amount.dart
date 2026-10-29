import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_highlight_line.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// مال المدى المختار بحجمه، وتحته نسبته إلى الفترة التي قبله.
///
/// النسبة تصل محسوبة من رقمي القاعدة، فتُطبع أمام أساسها مرة واحدة: تكرارها
/// في الترويسة والتذييل يجعل رقمًا واحدًا ثلاثة أرقام في شاشة واحدة.
class DashboardSalesAmount extends StatelessWidget {
  const DashboardSalesAmount({
    super.key,
    required this.amount,
    required this.trend,
  });

  final double amount;

  /// نسبة المال إلى المدى السابق، و`null` حين لا أساس يُقارَن به.
  final AdminMetricTrend? trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = trend;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                localizeDigits(formatAmount(amount)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size22,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_3,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.px4),
            CurrencyIcon(size: 20, color: adminMutedColor(theme)),
          ],
        ),
        if (delta != null) ...[
          const SizedBox(height: AppSizes.px6),
          AdminHighlightLine(
            before: '',
            value: delta.label,
            after: S.dashboardVsPreviousPeriod,
            maxLines: 1,
            valueColor: delta.positive
                ? AppColor.trendPositive
                : AppColor.trendNegative,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size8,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ],
    );
  }
}
