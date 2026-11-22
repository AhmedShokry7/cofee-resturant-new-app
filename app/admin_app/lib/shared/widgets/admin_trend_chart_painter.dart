import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/admin_trend_chart_geometry.dart';

/// يرسم منحنى اتجاه ناعم فوق شبكة أفقية مع مساحة متدرجة وتحديد آخر قيمة.
///
/// الرسم هندسة خالصة: القيم والألوان تصل إليه محسوبة، فلا يعرف شيئًا عن
/// الطلبات ولا عن القاعدة ولا عن لغة الأرقام المعروضة.
///
/// وعند تمرير [hoverIndex] يرسم خطًا رأسيًا هادئًا وحلقة حول النقطة المشار
/// إليها، فتُقرأ النقطة التي يقف عليها المؤشر بلا تلميحة ظاهرة بعد.
class AdminTrendChartPainter extends CustomPainter {
  const AdminTrendChartPainter({
    required this.values,
    required this.progress,
    required this.lineColor,
    required this.gridColor,
    this.gridLines = trendGridLines,
    this.hoverIndex,
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

  /// النقطة التي يقف عليها المؤشر، أو `null` حين لا مؤشر على اللوحة.
  final int? hoverIndex;

  /// هامش الرسم كي لا تُقصّ الحواف، وهو أيضًا نصف قطر نقطة النهاية.
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
    _paintDayDots(canvas, points);
    canvas.drawCircle(points.last, _margin, Paint()..color = lineColor);
    final hover = hoverIndex;
    if (hover != null && hover >= 0 && hover < points.length) {
      _paintHover(canvas, size, points[hover]);
    }
  }

  /// نقطة صغيرة عند كل يوم: كل يوم يُرى على المنحنى بلا تلميحة.
  ///
  /// تظهر بعد اكتمال نصف الرسم كي لا تصطف قبل أن يرسم الخط ما بينها.
  void _paintDayDots(Canvas canvas, List<Offset> points) {
    final alpha = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final paint = Paint()..color = lineColor.withValues(alpha: .9 * alpha);
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawCircle(points[i], 2.2, paint);
    }
  }

  /// خط رأسي إلى أرضية اللوحة وحلقة مفرغة حول النقطة المشارة إليها.
  void _paintHover(Canvas canvas, Size size, Offset point) {
    final line = Paint()
      ..color = lineColor.withValues(alpha: .35)
      ..strokeWidth = AppSizes.px1;
    canvas.drawLine(
      Offset(point.dx, point.dy + 8),
      Offset(point.dx, size.height),
      line,
    );
    canvas.drawCircle(
      point,
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.px2
        ..color = lineColor,
    );
    canvas.drawCircle(
      point,
      3.5,
      Paint()..color = lineColor.withValues(alpha: .18),
    );
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
  bool shouldRepaint(AdminTrendChartPainter oldDelegate) =>
      oldDelegate.values.length != values.length ||
      oldDelegate.progress != progress ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.gridLines != gridLines ||
      oldDelegate.hoverIndex != hoverIndex;
}
