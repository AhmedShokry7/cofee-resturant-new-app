import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_highlight_line.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// جملة الشريط: خبرٌ فوق نسبته، والنسبة وحدها ملوّنة.
///
/// العنوان منفصل عن الرقم لأن القارئ يسأل «ماذا حدث؟» قبل «بكم؟»؛ والفترة
/// تُنسب إليها النسبة فيُقال مداها لا يترك للأدمن أن يخمّن أي نافذة نمَت.
class DashboardGrowthHeadline extends StatelessWidget {
  const DashboardGrowthHeadline({
    super.key,
    required this.percent,
    required this.period,
  });

  /// النسبة كما حسبها الشريط من رقمي القاعدة، مع إشارتها.
  final String percent;

  /// المدى المختار: «عن الشهر الماضي» أو «عن الأسبوع الماضي».
  final String period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.dashboardGrowthHeadline,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminHeadingColor(theme),
            fontSize: AppFontSizes.size11,
            fontWeight: AppFontWeights.bold,
            height: AppTextHeights.line1_5,
          ),
        ),
        AdminHighlightLine(
          before: S.dashboardGrowthUp,
          value: percent,
          after: '$period. ${S.dashboardGrowthKeepGoing}',
          valueColor: AppColor.trendPositive,
          style: TextStyle(
            color: adminBodyColor(theme),
            fontSize: AppFontSizes.size9_5,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}
