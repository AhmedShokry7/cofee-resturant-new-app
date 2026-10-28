import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/admin_donut_centre.dart';
import 'package:admin_app/shared/widgets/admin_donut_chart_painter.dart';
import 'package:admin_app/shared/widgets/admin_donut_slice.dart';

export 'package:admin_app/shared/widgets/admin_donut_slice.dart'
    show AdminDonutSlice;

/// دونات نسبي يعرض توزيع القيم مع رقم مركزي اختياري في فتحته.
class AdminDonutChart extends StatelessWidget {
  const AdminDonutChart({
    super.key,
    required this.slices,
    this.size = AppDimensions.donutSize,
    this.strokeWidth = AppDimensions.donutThickness,
    this.centerValue,
    this.centerLabel,
  });

  /// القطع المعروضة؛ تُفصل بفجوة صغيرة وتُحسب نسبها من مجموع قيمها.
  final List<AdminDonutSlice> slices;

  /// قطر الرسم كاملًا.
  final double size;

  /// سماكة حلقة الدونات.
  final double strokeWidth;

  /// الرقم الكبير في فتحة الدونات.
  final String? centerValue;

  /// التسمية الصغيرة تحت الرقم المركزي.
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.brightness == Brightness.dark
        ? AppColor.darkBorder
        : AppColor.adminRowBorder;
    final instant = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (instant)
            _ring(trackColor, 1)
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: AppDimensions.chartRevealDuration,
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => _ring(trackColor, progress),
            ),
          if (centerValue != null)
            AdminDonutCentre(value: centerValue!, label: centerLabel),
        ],
      ),
    );
  }

  /// يرسم الحلقة عند نسبة ظهور معيّنة فوق مسارها الهادئ.
  Widget _ring(Color trackColor, double progress) => CustomPaint(
    size: Size.square(size),
    painter: AdminDonutChartPainter(
      slices: slices,
      strokeWidth: strokeWidth,
      progress: progress,
      trackColor: trackColor,
    ),
  );
}
