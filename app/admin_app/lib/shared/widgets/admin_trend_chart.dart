import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_trend_axis_labels.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_geometry.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_painter.dart';
import 'package:admin_app/shared/widgets/admin_trend_point.dart';
import 'package:admin_app/shared/widgets/admin_trend_value_axis.dart';

export 'package:admin_app/shared/widgets/admin_trend_point.dart'
    show AdminTrendPoint;

/// منحنى اتجاه تفاعلي: ناعم، كل يوم نقطتُه ظاهرة، وتمرير المؤشر يُظهر
/// تلميحة تقرأ اليوم وقيمته.
///
/// التسميات تُطبع تحت اللوحة لا داخلها، كي يبقى الرسم هندسة ولا يعرف شيئًا
/// عن الأيام أو العملات: الصفحة تملك المعنى وهي التي تختار ما يُكتب،
/// والتلميحة تُبنى من حقول النقطة نفسها فلا يعرف الرسم عملة.
/// و[valueLabels] تختار عدد خطوط الشبكة بنفسها، فيقع كل رقم على خطّه.
class AdminTrendChart extends StatefulWidget {
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
  State<AdminTrendChart> createState() => _AdminTrendChartState();
}

class _AdminTrendChartState extends State<AdminTrendChart> {
  /// النقطة التي يقف فوقها المؤشر، أو `null` حين يترك المؤشر اللوحة.
  int? _hoverIndex;

  @override
  void dispose() {
    _hoverIndex = null;
    super.dispose();
  }

  /// نصف قطر نقطة الرسم نفسه: هامش اللوحة الذي ترسم به الهندسة.
  static const double _margin = AppSizes.px4;

  void _onHover(PointerEvent event, double width) {
    final count = widget.points.length;
    final step = (width - _margin * 2) / (count - 1);
    final index = ((event.localPosition.dx - _margin) / step)
        .round()
        .clamp(0, count - 1)
        .toInt();
    if (_hoverIndex != index) setState(() => _hoverIndex = index);
  }

  void _onExit() {
    if (_hoverIndex != null) setState(() => _hoverIndex = null);
  }

  /// موضع النقطة داخل اللوحة، بنفس حسابات [trendPointPositions].
  Offset _pointPosition(double width, int index) {
    final values = [for (final point in widget.points) point.value];
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final flat =
        maxValue <= 0 || values.every((value) => value == values.first);
    final step = (width - _margin * 2) / (values.length - 1);
    final usableHeight = widget.height - _margin * 2;
    return Offset(
      _margin + step * index,
      flat
          ? widget.height / 2
          : widget.height - _margin - usableHeight * values[index] / maxValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = widget.valueLabels;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labels != null) ...[
          AdminTrendValueAxis(labels: labels, height: widget.height),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: _plotColumn(context, theme, labels?.length)),
      ],
    );
  }

  /// اللوحة فوق تسمياتها الأفقية، مع ظهور تدريجي ما لم تُطلب الحركة off،
  /// والمؤشر فوقها يُظهر خطه وحلقته وتلميحته.
  Widget _plotColumn(BuildContext context, ThemeData theme, int? gridLines) {
    final lineColor = AppColor.primaryColor;
    final gridColor = adminRowBorderColor(theme);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: MediaQuery.disableAnimationsOf(context)
              ? _interactivePlot(
                  _plot(lineColor, gridColor, gridLines, 1),
                  theme,
                )
              : TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AppDimensions.chartRevealDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) => _interactivePlot(
                    _plot(lineColor, gridColor, gridLines, progress),
                    theme,
                    progress: progress,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AdminTrendAxisLabels(
          points: widget.points,
          labelCount: widget.labelCount,
          highlightIndex: _hoverIndex,
        ),
      ],
    );
  }

  /// اللوحة داخل منطقة مؤشّر: تتبع الحركة ثم تلميحة عند نقطة معلومة.
  Widget _interactivePlot(
    Widget painted,
    ThemeData theme, {
    double progress = 1,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final hover = _hoverIndex;
      final paintedWithHover = hover == null
          ? painted
          : _plot(
              AppColor.primaryColor,
              adminRowBorderColor(theme),
              widget.valueLabels?.length,
              progress,
              hover,
            );
      return MouseRegion(
        cursor: SystemMouseCursors.precise,
        onHover: (event) => _onHover(event, width),
        onExit: (_) => _onExit(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: paintedWithHover),
            if (hover != null) _tooltip(width, theme, hover, progress),
          ],
        ),
      );
    },
  );

  /// تلميحة اليوم المشارة إليها، تقفز من نقطة إلى أخرى بحركة هادئة.
  Widget _tooltip(double width, ThemeData theme, int index, double progress) {
    final point = widget.points[index];
    final position = _pointPosition(
      width,
      index,
    ).scale(progress.clamp(0.0, 1.0), 1.0);
    final title = point.tooltipTitle ?? point.label;
    final value = point.tooltipValue;
    final detail = point.tooltipDetail;
    const tooltipWidth = 150.0;
    final left = (position.dx - tooltipWidth / 2).clamp(
      2.0,
      (width - tooltipWidth - 2).clamp(2.0, double.infinity),
    );
    final top = position.dy - 74;
    final dark = theme.brightness == Brightness.dark;
    return AnimatedPositioned(
      duration: AppDimensions.chartRevealDuration ~/ 3,
      curve: Curves.easeOutCubic,
      left: left,
      top: top < 2 ? position.dy + 12 : top,
      child: AnimatedOpacity(
        duration: AppDimensions.chartRevealDuration ~/ 4,
        opacity: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: tooltipWidth),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSizes.px6,
          ),
          decoration: BoxDecoration(
            color: dark ? AppColor.darkSurfaceContainer : AppColor.darkSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: AppFontSizes.size8,
                  height: AppTextHeights.line1_4,
                ),
              ),
              if (value != null)
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              if (detail != null)
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontSize: AppFontSizes.size8,
                    height: AppTextHeights.line1_4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// يرسم اللوحة عند نسبة ظهور معيّنة بألوان الثيم الحالي.
  Widget _plot(
    Color lineColor,
    Color gridColor,
    int? gridLines, [
    double progress = 1,
    int? hoverIndex,
  ]) => CustomPaint(
    size: Size.infinite,
    painter: AdminTrendChartPainter(
      values: [for (final point in widget.points) point.value],
      progress: progress,
      lineColor: lineColor,
      gridColor: gridColor,
      gridLines: gridLines ?? trendGridLines,
      hoverIndex: hoverIndex,
    ),
  );
}
