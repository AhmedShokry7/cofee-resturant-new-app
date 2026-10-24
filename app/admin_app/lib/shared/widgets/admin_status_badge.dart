import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';

/// A small pill that names a state with its colour.
///
/// The label is always shown, so the badge never relies on colour alone, and
/// the pale background keeps it readable on both a light and a dark surface.
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  /// A background pale enough to carry a dark text on any surface.
  Color get _background => Color.lerp(color, Colors.white, 0.86)!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: dark ? color.withValues(alpha: 0.25) : _background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: dark ? color : color.withValues(alpha: 1),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
