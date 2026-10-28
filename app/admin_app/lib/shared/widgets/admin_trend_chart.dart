import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_trend_axis_labels.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_geometry.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_painter.dart';
import 'package:admin_app/shared/widgets/admin_trend_point.dart';
import 'package:admin_app/shared/widgets/admin_trend_value_axis.dart';

export 'package:admin_app/shared/widgets/admin_trend_point.dart'
    show AdminTrendPoint;

/// منحنى اتجاه ناعم مع منطقة متدرجة وتسميات محور منتظمة أسفله.
///
/// التسميات تُطبع تحت اللوحة لا داخلها، كي يبقى الرسم هندسة ولا يعرف شيئًا عن
/// الأيام أو العملات: الصفحة تملك المعنى وهي التي تختار ما يُكتب. و[valueLabels]
/// تختار عدد خطوط الشبكة بنفسها، فيقع كل رقم على خطّه.
class AdminTrendChart extends StatelessWidget {
  const AdminTrendChart({
    super.key,
    required this.points,
    this.height = AppDimensions.trendChartHeight,
    this.labelCount = AppDimensions.trendChartLabelCount,
    this.valueLabels,
  }) : assert(points.length >= 2);

  /// النقاط من الأقدم إلى الأحدث، ولا بد أن تكون اثنتين على الأقل.
  final List<AdminTrendPoint> points;

  /// ارتفاع منطقة الرسم دون صف التسميات.
  final double height;

  /// عدد تسميات المحور المطبوعة بانتظام، وآخرها تسمية أحدث نقطة.
  final int labelCount;

  /// تسميات المحور الرأسي من أعلى اللوحة إلى أسفلها، وتحجب حين تُترك.
  final List<String>? valueLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = valueLabels;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labels != null) ...[
          AdminTrendValueAxis(labels: labels, height: height),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: _plotColumn(context, theme, labels?.length)),
      ],
    );
  }

  /// اللوحة فوق تسمياتها الأفقية، مع ظهور تدريجي ما لم تُطلب الحركة off.
  Widget _plotColumn(BuildContext context, ThemeData theme, int? gridLines) {
    final lineColor = AppColor.primaryColor;
    final gridColor = adminRowBorderColor(theme);
    final plot = _plot(lineColor, gridColor, gridLines);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: MediaQuery.disableAnimationsOf(context)
              ? plot
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AppDimensions.chartRevealDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) =>
                      _plot(lineColor, gridColor, gridLines, progress),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AdminTrendAxisLabels(points: points, labelCount: labelCount),
      ],
    );
  }

  /// يرسم اللوحة عند نسبة ظهور معيّنة بألوان الثيم الحالي.
  Widget _plot(
    Color lineColor,
    Color gridColor,
    int? gridLines, [
    double progress = 1,
  ]) => CustomPaint(
    painter: AdminTrendChartPainter(
      values: [for (final point in points) point.value],
      progress: progress,
      lineColor: lineColor,
      gridColor: gridColor,
      gridLines: gridLines ?? trendGridLines,
    ),
  );
}
