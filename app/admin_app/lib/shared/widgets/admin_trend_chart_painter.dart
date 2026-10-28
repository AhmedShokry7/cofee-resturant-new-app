import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_geometry.dart';

/// يرسم منحنى اتجاه ناعم فوق شبكة أفقية مع مساحة متدرجة وتحديد آخر قيمة.
///
/// الرسم هندسة خالصة: القيم والألوان تصل إليه محسوبة، فلا يعرف شيئًا عن
/// الطلبات ولا عن القاعدة ولا عن لغة الأرقام المعروضة.
class AdminTrendChartPainter extends CustomPainter {
  const AdminTrendChartPainter({
    required this.values,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
    this.gridLines = trendGridLines,
  });

  /// القيم المرسومة من الأقدم إلى الأحدث، وتنمو من الأسفل بحسب [progress].
  final List<double> values;

  /// نسبة الظهور من 0 إلى 1، وتُقصّ قبل الرسم.
  final double progress;

  /// لون الخط والمساحة المتدرجة تحته.
  final Color lineColor;

  /// لون خطوط الشبكة الأفقية.
  final Color gridColor;

  /// عدد خطوط الشبكة، ويساوي تسميات المحور الرأسي حين تُطبع.
  final int gridLines;

  /// نصف قطر نقطة النهاية، وهو أيضًا هامش الرسم كي لا تُقصّ الحواف.
  static const double _margin = AppSizes.px4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    paintTrendGrid(canvas, size, gridColor, lineCount: gridLines);
    if (values.length < 2) return;

    final points = trendPointPositions(
      values: values,
      size: size,
      progress: progress,
      margin: _margin,
    );
    final line = smoothTrendPath(points);
    canvas.drawPath(_area(line, points, size), _areaPaint(size));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.px2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor,
    );
    canvas.drawCircle(points.last, _margin, Paint()..color = lineColor);
  }

  /// المساحة المحصورة بين الخط وأرضية اللوحة.
  Path _area(Path line, List<Offset> points, Size size) => Path.from(line)
    ..lineTo(points.last.dx, size.height)
    ..lineTo(points.first.dx, size.height)
    ..close();

  /// تدرّج المنطقة: لون الخط نفسه ذابلًا إلى الشفافية نحو الأسفل.
  Paint _areaPaint(Size size) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: AppDimensions.trendAreaTopAlpha),
        lineColor.withValues(alpha: 0),
      ],
    ).createShader(Offset.zero & size);

  @override
  bool shouldRepaint(AdminTrendChartPainter oldDelegate) {
    if (oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.values.length != values.length) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
