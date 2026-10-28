import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// شريط تقدم مستدير يعرض نسبة محسوبة داخل مسار هادئ،
/// ويملأ نفسه مرة واحدة عند أول ظهور ليجذب العين إلى القيمة.
class AdminProgressBar extends StatelessWidget {
  const AdminProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height,
  });

  /// النسبة المعروضة؛ تُقصّ إلى المدى 0..1 قبل الرسم.
  final double value;

  /// لون الامتلاء، والافتراضي لون الثيم الأساسي.
  final Color? color;

  /// ارتفاع الشريط، والافتراضي [AppSizes.px8].
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = theme.brightness == Brightness.dark
        ? AppColor.darkBorder
        : AppColor.adminRowBorder;
    final fillColor = color ?? theme.colorScheme.primary;
    final barHeight = height ?? AppSizes.px8;
    final fraction = value.clamp(0.0, 1.0);
    final instant = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor),
            if (instant)
              _fill(fillColor, fraction)
            else
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: fraction),
                duration: AppDimensions.chartRevealDuration,
                curve: Curves.easeOutCubic,
                builder: (context, animated, _) => _fill(fillColor, animated),
              ),
          ],
        ),
      ),
    );
  }

  /// يملأ الشريط من بداية السطر حسب اتجاه اللغة.
  Widget _fill(Color color, double factor) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: factor,
      heightFactor: 1,
      child: ColoredBox(color: color),
    ),
  );
}
