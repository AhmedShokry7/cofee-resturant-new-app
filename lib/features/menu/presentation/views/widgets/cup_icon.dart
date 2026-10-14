import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/menu/data/product_variants.dart';

/// Takeaway-cup illustration, drawn in code so it stays sharp at any size.
/// The cup grows with the drink size: S < M < L.
class CupIcon extends StatelessWidget {
  const CupIcon({super.key, required this.size, required this.selected});

  final DrinkSize size;
  final bool selected;

  double get _height {
    switch (size) {
      case DrinkSize.small:
        return 20;
      case DrinkSize.medium:
        return 26;
      case DrinkSize.large:
        return 32;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColor.primaryColor : AppColor.greyColor;
    return CustomPaint(
      size: Size((_height * 0.72).w, _height.h),
      painter: _CupPainter(color: color),
    );
  }
}

class _CupPainter extends CustomPainter {
  const _CupPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // Lid.
    final lidHeight = h * 0.14;
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, 0, w * 0.88, lidHeight),
      const Radius.circular(2),
    );
    canvas.drawRRect(lid, fillPaint);
    canvas.drawRRect(lid, bodyPaint);

    // Body (tapered: wider on top).
    final topY = lidHeight * 0.9;
    final body = Path()
      ..moveTo(w * 0.12, topY)
      ..lineTo(w * 0.28, h)
      ..lineTo(w * 0.72, h)
      ..lineTo(w * 0.88, topY)
      ..close();
    canvas.drawPath(body, fillPaint);
    canvas.drawPath(body, bodyPaint);

    // Sleeve band.
    final sleeveTop = topY + (h - topY) * 0.38;
    final sleeveBottom = topY + (h - topY) * 0.62;
    final leftTop = _lerp(w * 0.12, w * 0.28, 0.38);
    final leftBottom = _lerp(w * 0.12, w * 0.28, 0.62);
    final rightTop = _lerp(w * 0.88, w * 0.72, 0.38);
    final rightBottom = _lerp(w * 0.88, w * 0.72, 0.62);
    final sleeve = Path()
      ..moveTo(leftTop, sleeveTop)
      ..lineTo(leftBottom, sleeveBottom)
      ..lineTo(rightBottom, sleeveBottom)
      ..lineTo(rightTop, sleeveTop)
      ..close();
    final sleevePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(sleeve, sleevePaint);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _CupPainter oldDelegate) =>
      oldDelegate.color != color;
}
