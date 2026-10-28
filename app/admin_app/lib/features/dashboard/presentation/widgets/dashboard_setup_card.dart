import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_setup_row.dart';
import 'package:admin_app/shared/widgets/admin_progress_bar.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// خطوات بداية المتجر، وعدّادها أمامها.
///
/// كل خطوة تُقرأ من جدول حقيقي في القاعدة، فـ«٢/٤» عددٌ لا زينة: لا خطوة تُعلَّم
/// تمت بيد الأدمن، ولا خطوة تُعرض لمن لا سلطة له على فعلها — من لا يدير كل
/// الفروع لا يُلام على صورة فرع لا يملكه.
class DashboardSetupCard extends StatelessWidget {
  const DashboardSetupCard({super.key, required this.metrics});

  final AdminDashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = dashboardVisibleSetupSteps(metrics);
    final done = steps.where((step) => step.done).length;
    return AdminSectionCard(
      title: S.dashboardSetupTitle,
      subtitle: S.dashboardSetupSubtitle,
      leading: _counter(theme, done, steps.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminProgressBar(
            value: done / steps.length,
            height: AppSizes.px4,
            color: AppColor.adminAccent,
          ),
          const SizedBox(height: AppSizes.px8),
          for (final (index, step) in steps.indexed)
            DashboardSetupRow(step: step, position: index + 1),
        ],
      ),
    );
  }

  /// «المُنجَز من الكل» مكتوبًا رقمًا: الشريط وحده يُقاس بالعين، والعدد يُقال.
  Widget _counter(ThemeData theme, int done, int total) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.px6,
      vertical: AppSizes.px4,
    ),
    decoration: BoxDecoration(
      color: adminFlagBackground(
        theme,
        AppColor.trendPositive,
        AppColor.tintGreenSurface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      localizeDigits('$done/$total'),
      style: TextStyle(
        color: adminFlagForeground(theme, AppColor.trendPositive),
        fontSize: AppFontSizes.size8,
        height: AppTextHeights.line1_4,
      ),
    ),
  );
}
