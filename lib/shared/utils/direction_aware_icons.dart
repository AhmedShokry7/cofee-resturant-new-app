import 'package:flutter/widgets.dart';
import 'package:new_coffee/core/theme/app_icons.dart';

/// Resolves logical navigation icons so they point toward the start (back) or
/// end (forward) of the current reading direction.
///
/// Back navigation points left in LTR and right in RTL; forward navigation
/// points right in LTR and left in RTL. The icon set ships distinct left/right
/// glyphs rather than auto-mirroring, so this helper is the single place that
/// maps logical intent to the right glyph for the active [Directionality].
///
/// Non-directional icons (cart, heart, location pin, …) are intentionally not
/// part of this helper and must keep their fixed glyph regardless of locale.
class DirectionAwareIcons {
  DirectionAwareIcons._();

  /// The glyph for logical "back" navigation.
  ///
  /// Points toward the start of the reading direction: `ArrowLeft01` in LTR,
  /// `ArrowRight01` in RTL.
  static IconData back(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? AppIcons.forward
      : AppIcons.back;

  /// The glyph for logical "forward / next" navigation.
  ///
  /// Points toward the end of the reading direction: `ArrowRight01` in LTR,
  /// `ArrowLeft01` in RTL.
  static IconData forward(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? AppIcons.back
      : AppIcons.forward;
}
