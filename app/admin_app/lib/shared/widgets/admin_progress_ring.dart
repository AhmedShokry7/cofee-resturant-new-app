import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/admin_ring_painter.dart';

/// حلقة تقدّم بنسبة واحدة أمام مسارها الكامل، ومعناها في فتحتها.
///
/// الشريط المستطيل يقول «كم بقي» ولا يعطي شكل النسبة من دائرة، والحلقة تُقرأ
/// من زاويتها من أول نظرة؛ وهي الشكل الذي تختاره اللوحة حين يكون الرقم المركزي
/// هو الخبر. وما في الفتحة تُسلّمه الصفحة، فالحلقة هندسة لا تعرف عملات ولا
/// أهدافًا، وتملأ نفسها مرة واحدة عند أول رسم كبقية رسوم اللوحة.
class AdminProgressRing extends StatelessWidget {
  const AdminProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = AppDimensions.donutSize,
    this.strokeWidth = AppSizes.px8,
    this.color,
  });

  /// نسبة الامتلاء من ٠ إلى ١، وتُقصّ قبل الرسم فلا تتجاوز الحلقة نفسها.
  final double value;

  /// ما يُطبع في الفتحة: رقم النسبة وتسميتها.
  final Widget child;

  final double size;
  final double strokeWidth;

  /// لون القوس، والافتراضي أخضر الإدارة.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.brightness == Brightness.dark
        ? AppColor.darkBorder
        : AppColor.adminRowBorder;
    final fillColor = color ?? AppColor.adminAccent;
    final fraction = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (MediaQuery.disableAnimationsOf(context))
            _ring(trackColor, fillColor, fraction)
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fraction),
              duration: AppDimensions.chartRevealDuration,
              curve: Curves.easeOutCubic,
              builder: (context, animated, _) =>
                  _ring(trackColor, fillColor, animated),
            ),
          child,
        ],
      ),
    );
  }

  Widget _ring(Color trackColor, Color fillColor, double fraction) =>
      CustomPaint(
        size: Size.square(size),
        painter: AdminRingPainter(
          fraction: fraction,
          strokeWidth: strokeWidth,
          trackColor: trackColor,
          fillColor: fillColor,
        ),
      );
}
