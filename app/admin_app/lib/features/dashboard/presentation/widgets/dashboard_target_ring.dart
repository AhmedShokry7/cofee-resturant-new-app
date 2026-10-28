import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/shared/widgets/admin_progress_ring.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// حلقة نسبة الشهر المنقضية من هدفه.
///
/// النسبة من رقمي القاعدة قسمةً، وهي تُقصّ عند تمام الحلقة: منجاوزٌ هدفه تُقال
/// بتمام الحلقة لا بحلقة تخرج من البطاقة. والـ١٠٠٪ تُطبع كما تحسبها `formatPercent`
/// لا كما تُقرَّب للعين، فلا تُقرأ نسبةٌ رقمين.
class DashboardTargetRing extends StatelessWidget {
  const DashboardTargetRing({
    super.key,
    required this.progress,
    required this.reached,
  });

  /// نسبة المحقَّق من الهدف، بين ٠ و١ كما حسبها العرض من رقمين.
  final double progress;

  /// بلوغ الهدف يقلب لون الحلقة: الأخضر خبرٌ، والانتظار بعده ضجيج.
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = reached ? AppColor.trendPositive : AppColor.adminAccent;
    return AdminProgressRing(
      value: progress,
      color: ink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPercent(progress * 100),
            maxLines: 1,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size24,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_2,
            ),
          ),
          Text(
            S.dashboardOfTarget,
            maxLines: 1,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_3,
            ),
          ),
        ],
      ),
    );
  }
}
