import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The one way the app draws a glyph: size and colour come from the theme and
/// [AppIconSize], so a screen never writes an icon size or an icon colour.
///
/// The glyph itself always comes from [AppIcons]; `hugeicons` is not imported
/// outside the index file.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.muted = false,
  });

  final IconData icon;

  /// Overrides the size this icon's role asks for - a hero mark, or a glyph set
  /// beside 10pt text.
  final double? size;

  /// Overrides the theme colour, for a glyph drawn on a filled button.
  final Color? color;

  /// The secondary reading of the glyph: the same shape, one step quieter.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      icon,
      size: size ?? AppIconSize.xl,
      color:
          color ??
          (muted ? scheme.onSurfaceVariant : IconTheme.of(context).color) ??
          scheme.onSurface,
    );
  }
}
