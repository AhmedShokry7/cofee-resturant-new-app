import 'dart:math' as math;

import 'package:flutter/material.dart';

/// يرسم قوسًا من رأس الدائرة معقَّمًا حتى [fraction] فوق مسار كامل.
///
/// القوس يبدأ من أعلى لا من يمين: النسبة تُقرأ كعقرب ساعة، ومبدأٌ عند الثلاث
/// يقرأه الأدمن نصفًا ثم يتردّد. والمسار الكامل يُرسم أولًا حتى يبقى للعين ما
/// تقارن به القوس، ثم يُرسم القوس فوقه.
class AdminRingPainter extends CustomPainter {
  const AdminRingPainter({
    required this.fraction,
    required this.strokeWidth,
    required this.trackColor,
    required this.fillColor,
  });

  final double fraction;
  final double strokeWidth;
  final Color trackColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, stroke..color = trackColor);
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      stroke..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(AdminRingPainter old) =>
      old.fraction != fraction ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}
