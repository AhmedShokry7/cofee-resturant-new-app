import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The grey pill every search entry is drawn with.
///
/// The Home bar is a tap target that opens the search page, the search page's
/// field is a real input — they are different widgets, but they must not be
/// different styles, so the geometry and the icon live here.
class SearchPill {
  SearchPill._();

  static double radius() => AppRadius.pill;

  static EdgeInsetsGeometry padding() =>
      EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md);

  static Widget icon() =>
      Icon(AppIcons.search, size: AppSizes.px20, color: AppColor.greyColor);

  /// The pill's fill, so a tap target and a real field are the same grey.
  static Color fill() => AppColor.lightGreyColor;

  /// The pill's corner as a border: a `Material` paints through it and an
  /// `InkWell` clips its splash to it, which a `Container` decoration could not.
  static ShapeBorder shape() =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius()));
}
