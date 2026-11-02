import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_circle_item.dart';

/// The home category row: one line of circles that walks sideways forever.
///
/// The chips repeat, so the row never runs out - every category passes in front
/// of the customer without them touching the screen. They can still swipe it
/// like any other row: the walk stops under the finger and starts again once
/// the finger is gone and they have had a moment to read where it landed.
class CategoryMarquee extends StatefulWidget {
  const CategoryMarquee({
    super.key,
    required this.categories,
    required this.onTap,
  });

  final List<CategoryModel> categories;

  /// Called with the chip the customer hit. The row does not decide what a
  /// category opens - [HomeCategoriesSection] does, the same way the grid did.
  final void Function(CategoryModel category) onTap;

  /// How fast the row travels, in logical pixels a second.
  ///
  /// A speed rather than a loop duration, so a shop with forty categories takes
  /// longer to come round without every name sliding past faster. This is about
  /// three quarters of the width of a chip a second: slow enough that a name
  /// can be read while it passes, fast enough that the row still shows it is
  /// moving rather than sitting stuck.
  static const double pixelsPerSecond = 16.0;

  /// How long one full turn of a row of [chipCount] chips takes.
  static Duration turnFor(int chipCount) => Duration(
    microseconds:
        (chipCount *
                CategoryCircleItem.slot /
                pixelsPerSecond *
                Duration.microsecondsPerSecond)
            .round(),
  );

  @override
  State<CategoryMarquee> createState() => _CategoryMarqueeState();
}

class _CategoryMarqueeState extends State<CategoryMarquee>
    with SingleTickerProviderStateMixin {
  /// The width at each end where the row fades away.
  ///
  /// A chip cut clean off at the section's margin reads as the end of the row;
  /// the fade says the rest is off-screen and still to come.
  static const double _edgeFade = AppSizes.px24;

  final ScrollController _scroll = ScrollController();
  late final AnimationController _walk = AnimationController(vsync: this)
    ..addListener(_followWalk);

  Timer? _resumeTimer;

  /// Whether a finger is on the row. The walk stays off while one is.
  bool _held = false;

  /// The system's reduce-motion answer: the row still scrolls by hand, it only
  /// stops moving on its own.
  bool _reduceMotion = false;

  /// The distance one full turn covers: every chip laid out once.
  double get _cycle => widget.categories.length * CategoryCircleItem.slot;

  /// One chip is nowhere to walk to, and a customer who asked for less motion
  /// should not get any.
  bool get _walks => !_reduceMotion && widget.categories.length > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncWalk();
  }

  @override
  void didUpdateWidget(covariant CategoryMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories.length != widget.categories.length) _syncWalk();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _walk.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Puts the loop's clock in step with the chips the row actually holds.
  void _syncWalk() {
    if (!_walks) {
      _resumeTimer?.cancel();
      _walk.stop();
      return;
    }
    _walk.duration = CategoryMarquee.turnFor(widget.categories.length);
    if (!_held && !_walk.isAnimating) _walk.repeat();
  }

  /// Moves the row to wherever this point of the loop puts it.
  void _followWalk() {
    if (!_scroll.hasClients || _cycle <= 0) return;
    _scroll.jumpTo(_cycle * _walk.value);
  }

  void _hold() {
    _held = true;
    _resumeTimer?.cancel();
    _walk.stop();
  }

  void _scheduleResume() {
    _held = false;
    _resumeTimer?.cancel();
    if (!_walks) return;
    _resumeTimer = Timer(MotionTokens.marqueeResumeHold, _resumeWalk);
  }

  void _resumeWalk() {
    if (!mounted || !_walks) return;
    // Carry on from the chips on screen rather than from the first category.
    // The row repeats every [_cycle] pixels, so the same offset one turn
    // earlier shows exactly the same thing and the jump is invisible.
    final offset = _scroll.hasClients ? _scroll.offset % _cycle : 0.0;
    _walk.value = offset / _cycle;
    _walk.repeat();
  }

  /// How many copies of the list the row lays out.
  ///
  /// One category is not a string of chips to repeat, so it stands alone. Two
  /// or more get copies: at least two, because the loop rolls from the end of
  /// the first turn into the second, plus enough more that the screen stays
  /// full of chips at the moment the walk wraps back to the start.
  int _copies(double viewportWidth) {
    if (widget.categories.length < 2) return 1;
    return math.max(2, (viewportWidth / _cycle).ceil() + 1);
  }

  /// The fraction of the row each edge fade covers, so it stays [_edgeFade]
  /// wide however wide the row is.
  double _fadeStop(double width) =>
      math.min(_edgeFade / math.max(width, 1.0), 0.4);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final copies = _copies(constraints.maxWidth);
        final stop = _fadeStop(constraints.maxWidth);
        return Listener(
          onPointerDown: (_) => _hold(),
          onPointerUp: (_) => _scheduleResume(),
          onPointerCancel: (_) => _scheduleResume(),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (Rect bounds) => LinearGradient(
              colors: const [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, stop, 1.0 - stop, 1.0],
            ).createShader(bounds),
            child: SizedBox(
              height: CategoryCircleItem.height(context),
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                // Every chip the same width, so one turn of the loop is an
                // exact distance and the wrap cannot land a pixel out.
                itemExtent: CategoryCircleItem.slot,
                itemCount: widget.categories.length * copies,
                itemBuilder: (context, index) {
                  final category =
                      widget.categories[index % widget.categories.length];
                  return CategoryCircleItem(
                    category: category,
                    onTap: () => widget.onTap(category),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
