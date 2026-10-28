import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/admin_donut_slice.dart';

/// يرسم حلقات الدونات مع فجوات صغيرة ومسار خلفي، ويُظهرها تدريجيًا حتى [progress].
class AdminDonutChartPainter extends CustomPainter {
  const AdminDonutChartPainter({
    required this.slices,
    required this.strokeWidth,
    required this.progress,
    required this.trackColor,
  });

  /// القطع المرسومة بترتيبها.
  final List<AdminDonutSlice> slices;

  /// سماكة الحلقة.
  final double strokeWidth;

  /// نسبة الظهور من 0 إلى 1، وتُقصّ قبل الرسم.
  final double progress;

  /// لون المسار الكامل خلف القطع، ويظهر أيضًا داخل الفجوات.
  final Color trackColor;

  /// فجوة ثابتة بين كل قطعتين، بالدرجات.
  static const double _gapRadians =
      AppDimensions.donutGapDegrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    final visible = [
      for (final slice in slices)
        if (slice.value > 0) slice,
    ];
    final total = visible.fold<double>(0, (sum, slice) => sum + slice.value);
    final fraction = progress.clamp(0.0, 1.0);
    if (total <= 0 || fraction <= 0) return;

    final inset = visible.length > 1 ? _gapRadians : 0.0;
    var start = -math.pi / 2;
    for (final slice in visible) {
      final sweep = math.pi * 2 * slice.value / total * fraction;
      final gap = math.min(inset, sweep / 2);
      if (sweep > gap) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..color = slice.color,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(AdminDonutChartPainter oldDelegate) {
    if (oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.slices.length != slices.length) {
      return true;
    }
    for (var i = 0; i < slices.length; i++) {
      if (oldDelegate.slices[i].value != slices[i].value ||
          oldDelegate.slices[i].color != slices[i].color) {
        return true;
      }
    }
    return false;
  }
}
