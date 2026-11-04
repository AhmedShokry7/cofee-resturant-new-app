import 'dart:ui';

import 'package:new_coffee/core/theme/app_color.dart';

/// The brand colours the admin dashboard previews, read from the URL.
///
/// The preview opens this app with `?preview=1&primary=...&secondary=...` so a
/// draft theme can be seen before it is published. A device launches with no
/// query at all, so nothing here changes in normal use.
///
/// The override is only ever a preview: the real colours stay in the
/// configuration the app reads at runtime.
void applyPreviewTheme() {
  final params = Uri.base.queryParameters;
  if (params['preview'] != '1') return;

  final primary = _colorFromHex(params['primary']);
  if (primary != null) AppColor.primaryColor = primary;
  final secondary = _colorFromHex(params['secondary']);
  if (secondary != null) AppColor.secondryColor = secondary;
  final surface = _colorFromHex(params['surface']);
  if (surface != null) AppColor.cardSurface = surface;
}

/// A `#RRGGBB` (or `RRGGBB`) from the query string, or null when it is absent
/// or not a colour. An opaque colour is always the result, because a preview
/// that turned the brand transparent would be worse than no preview.
Color? _colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (value == null) return null;
  return Color(value | 0xFF000000);
}
