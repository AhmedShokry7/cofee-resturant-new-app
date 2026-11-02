import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/tokens.dart';

/// The inset every section of the home page shares, and the scroll padding the
/// page and its skeleton share.
///
/// Home does not read `AppLayout.pageBody`, even though that token carries the
/// same `lg` at the sides: the banner row is deliberately full-bleed, so the
/// list keeps only its vertical padding and every section insets itself. The
/// skeleton mirrors these two numbers so the page cannot jump when data lands.
class HomeSection extends StatelessWidget {
  const HomeSection({super.key, required this.child});

  final Widget child;

  /// The scroll padding of the loaded page and of its first-load skeleton.
  static const EdgeInsets bodyPadding = EdgeInsets.only(
    top: AppSpacing.md,
    bottom: AppSpacing.lg,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: child,
    );
  }
}
