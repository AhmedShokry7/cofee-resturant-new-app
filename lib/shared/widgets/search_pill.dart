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

  static BoxDecoration decoration() => BoxDecoration(
    color: AppColor.lightGreyColor,
    borderRadius: BorderRadius.circular(radius()),
  );
}
