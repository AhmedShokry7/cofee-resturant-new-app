import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';

/// Bottom panel whose top edge is the welcome organic curve.
///
/// Only this screen draws it, so it lives with the screen rather than in
/// `shared`. The clipper is intentionally asymmetric and fixed so the panel
/// keeps the same silhouette at any width; only the depth of the curve changes.
class WavyContainer extends StatelessWidget {
  const WavyContainer({
    super.key,
    required this.child,
    required this.curveHeight,
    this.color = AppColor.whiteColor,
    this.padding,
  });

  final Widget child;

  /// Depth of the curve, measured from its highest point to its deepest one, at
  /// the size the design was drawn. The only place that number is written.
  ///
  /// Callers scale it (`WavyContainer.designCurveDepth.h`) before handing it to
  /// [curveHeight]; there is no default, because an unscaled default drawn on a
  /// different screen is the wrong curve.
  static const double designCurveDepth = 55;

  /// [curveHeight] is the depth this instance is drawn at.
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
  const WavyTopClipper({required this.curveHeight});

  final double curveHeight;

  /// The horizontal weight of each part of the wave, as fractions of the width
  /// the design was drawn at.
  static const double _riseStart = 0.18;
  static const double _firstRiseEnd = 0.22;
  static const double _crestEnd = 0.48;
  static const double _fallStart = 0.72;
  static const double _tailStart = 0.78;

  /// The two heights the tail settles at, in logical pixels.
  static const double _tailHigh = 34;
  static const double _tailLow = 24;

  @override
  Path getClip(Size size) {
    // Keeps every control point in the same place as the design curve and only
    // scales the vertical offsets when the curve is resized.
    final scale = curveHeight / WavyContainer.designCurveDepth;

    final path = Path();

    path
      ..moveTo(0, curveHeight)
      // Smooth, asymmetric organic wave
      ..cubicTo(
        size.width * _riseStart,
        curveHeight,
        size.width * _firstRiseEnd,
        0,
        size.width * _crestEnd,
        0,
      )
      ..cubicTo(
        size.width * _fallStart,
        0,
        size.width * _tailStart,
        _tailHigh * scale,
        size.width,
        _tailLow * scale,
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
