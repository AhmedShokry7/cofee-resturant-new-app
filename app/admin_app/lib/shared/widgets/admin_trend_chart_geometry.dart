import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// عدد خطوط الشبكة الأفقية، والعلوي والسفلي منها على حافتي اللوحة.
const int trendGridLines = 4;

/// شبكة أفقية هادئة تعطي العين مقياسًا بصريًا بلا أرقام على المحور.
///
/// [lineCount] يساوي عدد تسميات المحور الرأسي حين تُطبع، فتقع كل تسمية على
/// خطّها بدل أن تقرأ الأدمن رقمًا في الفراغ بين خطّين.
void paintTrendGrid(
  Canvas canvas,
  Size size,
  Color color, {
  int lineCount = trendGridLines,
}) {
  final grid = Paint()
    ..color = color
    ..strokeWidth = AppSizes.px1;
  for (var i = 0; i < lineCount; i++) {
    final y = size.height * i / (lineCount - 1);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
  }
}

/// يحوّل قيم المنحنى إلى نقاط داخل [size]، من الأقدم إلى الأحدث.
///
/// أعلى قيمة تلمس الحافة العليا وأدناها الحافة السفلية: الرسم نسبي بطبيعته،
/// وأي محور ثابت كان سيخفي الفروق الصغيرة بين أيام متقاربة. السلسلة المسطّحة
/// تُرسم في منتصف الارتفاع، لأن قسمة على صفري المدى كانت ستقذف النقاط.
List<Offset> trendPointPositions({
  required List<double> values,
  required Size size,
  required double progress,
  required double margin,
}) {
  final maxValue = values.reduce(math.max);
  final flat = maxValue <= 0 || values.every((value) => value == values.first);
  final usableHeight = size.height - margin * 2;
  final step = (size.width - margin * 2) / (values.length - 1);
  final factor = progress.clamp(0.0, 1.0);
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        margin + step * i,
        flat
            ? size.height / 2
            : size.height -
                  margin -
                  usableHeight * values[i] / maxValue * factor,
      ),
  ];
}

/// يبني مسارًا سلسًا يمر قرب النقاط بوصلات تربيعية عند منتصفات ما بينها.
///
/// الوصل المستقيم يجعل منحنى المبيعات المتعرّج يبدو مكسّرًا؛ المنتصفات تجعل
/// الشكل قراءةً للاتجاه لا لتقلّب يوم واحد.
Path smoothTrendPath(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  return path..lineTo(points.last.dx, points.last.dy);
}
