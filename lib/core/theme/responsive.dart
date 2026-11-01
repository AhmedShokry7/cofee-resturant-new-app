import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The Material 3 window size classes, and the only thing a layout asks before
/// it changes shape.
///
/// This replaces ScreenUtil's design-width scaling: a spacing, an icon and a
/// font size stay fixed logical pixels, and the extra width buys content -
/// more columns and a capped measure - instead of enlarging everything. A
/// folded phone opened lands in [medium], a landscape tablet in [expanded].
enum AppWindowSize { compact, medium, expanded, large }

/// The window measurements a page builds its layout decisions on.
class ResponsiveMetrics {
  const ResponsiveMetrics({required this.size});

  final Size size;

  AppWindowSize get windowSize {
    final width = size.width;
    if (width < AppBreakpoints.medium) return AppWindowSize.compact;
    if (width < AppBreakpoints.expanded) return AppWindowSize.medium;
    if (width < AppBreakpoints.large) return AppWindowSize.expanded;
    return AppWindowSize.large;
  }

  /// One column on a phone, two on a folded phone or portrait tablet, three
  /// once the window is genuinely wide.
  int get contentColumns => switch (windowSize) {
    AppWindowSize.compact => 1,
    AppWindowSize.medium => 2,
    AppWindowSize.expanded || AppWindowSize.large => 3,
  };

  /// How wide page content may get, so a paragraph never stretches across a
  /// whole desktop window.
  double get contentMaxWidth => windowSize.index >= AppWindowSize.expanded.index
      ? AppBreakpoints.contentMaxWidth
      : double.infinity;

  /// The side gutter: `lg` on a phone, `xl` once the window has room for it.
  double get pageHorizontalPadding =>
      windowSize == AppWindowSize.compact ? AppSpacing.lg : AppSpacing.xl;
}

/// Every screen's way in: `context.windowSize` and `context.gridColumns()`,
/// with no breakpoint number written in the page.
extension ResponsiveContext on BuildContext {
  ResponsiveMetrics get responsive =>
      ResponsiveMetrics(size: MediaQuery.sizeOf(this));

  AppWindowSize get windowSize => responsive.windowSize;

  /// A phone: one column, sheets full width.
  bool get isCompact => windowSize == AppWindowSize.compact;

  /// A folded phone opened or a portrait tablet.
  bool get isMedium => windowSize == AppWindowSize.medium;

  /// Anything wider than a phone, folded phones and tablets included.
  bool get isWide => windowSize.index >= AppWindowSize.medium.index;

  /// A landscape tablet or a desktop window: side rails rather than drawers.
  bool get isExpandedOrLarger =>
      windowSize.index >= AppWindowSize.expanded.index;

  /// How many [tileMinWidth] tiles fit across the window, capped at
  /// [maxColumns] so a card stops shrinking once the row is full.
  ///
  /// The count comes from the window, not from thresholds written per screen,
  /// so the same grid serves the phone, the folded phone and the tablet.
  int gridColumns({
    double tileMinWidth = AppBreakpoints.gridTileMinWidth,
    int maxColumns = AppBreakpoints.gridMaxColumns,
  }) {
    final window = responsive.size.width;
    final capped = window > responsive.contentMaxWidth
        ? responsive.contentMaxWidth
        : window;
    final available = capped - responsive.pageHorizontalPadding * 2;
    if (!available.isFinite || available <= 0) return 1;
    return (available / tileMinWidth).floor().clamp(1, maxColumns);
  }

  /// The widest a running-text column should get on this window.
  double get readingColumnWidth =>
      isWide ? AppBreakpoints.readingColumnMaxWidth : double.infinity;
}

/// Fills the screen on a phone and centres the same content on a wide window.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    required this.child,
    this.maxWidth,
    this.horizontalPadding,
    super.key,
  });

  final Widget child;

  /// Overrides the width the size class would pick, for a page with its own
  /// ceiling.
  final double? maxWidth;

  /// The side gutter, defaulting to the one the size class asks for.
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final metrics = context.responsive;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? metrics.contentMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding ?? metrics.pageHorizontalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}
