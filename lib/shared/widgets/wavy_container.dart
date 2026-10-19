import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';

/// Bottom panel whose top edge is the welcome organic curve.
///
/// The clipper is intentionally asymmetric and fixed so the panel keeps the
/// same silhouette at any width; only the depth of the curve is adjustable.
class WavyContainer extends StatelessWidget {
  const WavyContainer({
    super.key,
    required this.child,
    this.curveHeight = 55,
    this.color = AppColor.whiteColor,
    this.padding,
  });

  final Widget child;

  /// Depth of the curve measured from its highest point to its deepest point.
  /// Defaults to the 55 the design was drawn with.
  final double curveHeight;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: WavyTopClipper(curveHeight: curveHeight),
      child: ColoredBox(
        color: color,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

class WavyTopClipper extends CustomClipper<Path> {
  const WavyTopClipper({this.curveHeight = 55});

  final double curveHeight;

  static const double _referenceCurveHeight = 55;

  @override
  Path getClip(Size size) {
    // Keeps every control point in the same place as the reference curve and
    // only scales the vertical offsets when the curve is resized.
    final scale = curveHeight / _referenceCurveHeight;

    final path = Path();

    path
      ..moveTo(0, curveHeight)
      // Smooth, asymmetric organic wave
      ..cubicTo(
        size.width * 0.18,
        curveHeight,
        size.width * 0.22,
        0,
        size.width * 0.48,
        0,
      )
      ..cubicTo(
        size.width * 0.72,
        0,
        size.width * 0.78,
        34 * scale,
        size.width,
        24 * scale,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant WavyTopClipper oldClipper) =>
      oldClipper.curveHeight != curveHeight;
}
