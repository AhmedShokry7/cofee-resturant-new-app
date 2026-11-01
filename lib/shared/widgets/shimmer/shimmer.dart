import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/layout_tokens.dart';

/// Central configuration for every skeleton/shimmer loading widget.
///
/// Colors follow the current [Theme] brightness so skeletons stay subtle in
/// both light and dark mode, and derive from the existing [AppColor] tokens
/// instead of introducing a new palette.
class ShimmerColors {
  const ShimmerColors._();

  static Color baseOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColor.darkCard
      : AppColor.skeletonBase;

  static Color highlightOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColor.darkBorder
      : AppColor.skeletonHighlight;
}

/// Subtle sliding-highlight wrapper for skeleton content.
///
/// The [child] subtree must paint solid shapes (see [ShimmerBox],
/// [ShimmerLine], [ShimmerCircle]); a linear gradient sweeps across them.
/// One [Shimmer] owns exactly one animation controller, so callers should wrap
/// the smallest loading block that makes sense (one card, one section) to
/// keep the animation scoped instead of rebuilding whole screens.
///
/// When the platform requests reduced motion
/// ([MediaQuery.disableAnimationsOf]), the child renders statically with the
/// base color and no ticker is created.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  final Widget child;

  /// Duration of one highlight sweep.
  final Duration period;

  /// When false, renders [child] statically (still with base colors).
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final base = ShimmerColors.baseOf(context);
    final highlight = ShimmerColors.highlightOf(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Sweep the highlight from fully off-screen-left to fully
        // off-screen-right so the motion loops without a visible jump.
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            final center = -0.5 * width + t * 2 * width;
            return LinearGradient(
              colors: <Color>[base, highlight, base],
              stops: const <double>[0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromLTWH(center - width, 0, width * 2, bounds.height),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// Solid skeleton block. Must live inside a [Shimmer] to animate; on its own
/// it is a static neutral placeholder (used for image loading states where a
/// second animation must not compete with the surrounding skeleton).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? ShimmerColors.baseOf(context),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.zero),
      ),
    );
  }
}

/// Single skeleton text line. [width] may be a fixed value or a fraction of
/// the available space via [widthFactor] (mirrors how real titles/descriptions
/// occupy partial rows).
class ShimmerLine extends StatelessWidget {
  const ShimmerLine({
    super.key,
    this.width,
    this.widthFactor,
    this.height = 12,
    this.radius = 6,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
    if (widthFactor == null) return box;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: box,
    );
  }
}

/// Circular skeleton avatar/icon placeholder.
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: size,
      height: size,
      shape: BoxShape.circle,
      color: color,
    );
  }
}

/// The card a skeleton row sits in: a surface that follows the theme, the
/// shared hairline border and one radius.
///
/// Every skeleton used to copy this decoration out and hardcode a white
/// surface, so a loading screen in dark mode kept painting white cards.
BoxDecoration skeletonCardDecoration(
  BuildContext context, {
  double radius = LayoutTokens.cardRadius,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? AppColor.darkCard : AppColor.whiteColor,
    borderRadius: BorderRadius.circular(radius.r),
    border: Border.all(
      color: dark ? AppColor.darkBorder : AppColor.borderColor,
    ),
  );
}

/// The padding around a list of skeleton cards - the same [LayoutTokens.pageBody]
/// the loaded page uses, so the two cannot drift.
EdgeInsetsGeometry skeletonListPadding(BuildContext context) =>
    LayoutTokens.pageBody();
