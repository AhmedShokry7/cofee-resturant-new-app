import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// عدّادات «يومي» الثلاثة ومصدر كلٍّ منها.
///
/// `hr.attendance_metrics` تشتق الحضور والتأخير من الجداول المنشورة وحدها
/// والمدة من البصمة: صفرٌ مع دقيقتَي عمل ليس تناقضًا تُصلحه الشاشة، بل مصدران
/// مختلفان يُقالان وإلا ظنّ الموظف أن بصمته لم تُقرأ أصلًا.
class HrMyDayMetricsStrip extends StatelessWidget {
  const HrMyDayMetricsStrip({super.key, required this.metrics});

  final HrAttendanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AdminStatTile(
              icon: AppIcons.timer01,
              tint: AppColor.adminAccent,
              surface: AppColor.adminAccentSurface,
              label: S.hrPresentToday,
              value: localizeDigits('${metrics.presentShifts}'),
            ),
            AdminStatTile(
              icon: AppIcons.alert01,
              tint: AppColor.adminWarning,
              surface: AppColor.adminWarningSurface,
              label: S.hrColLate,
              value: localizeDigits('${metrics.lateMinutes}'),
            ),
            AdminStatTile(
              icon: AppIcons.clock01,
              tint: AppColor.adminInfo,
              surface: AppColor.adminInfoSurface,
              label: S.hrColWorked,
              value: hrDuration(metrics.workedMinutes),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          S.hrMetricsSources,
          style: TextStyle(
            color: adminMutedColor(Theme.of(context)),
            fontSize: AppFontSizes.size10_5,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }
}
