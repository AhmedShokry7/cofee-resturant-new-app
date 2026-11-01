import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';

/// The grey pill every search entry is drawn with.
///
/// The Home bar is a tap target that opens the search page, the search page's
/// field is a real input — they are different widgets, but they must not be
/// different styles, so the geometry and the icon live here.
class SearchPill {
  SearchPill._();

  static double radius() => 100.r;

  static EdgeInsetsGeometry padding() => EdgeInsets.symmetric(
    horizontal: SpacingTokens.lg.w,
    vertical: SpacingTokens.md.h,
  );

  static Widget icon() => Icon(
    HugeIcons.strokeRoundedSearch01,
    size: 20.w,
    color: AppColor.greyColor,
  );

  static BoxDecoration decoration() => BoxDecoration(
    color: AppColor.lightGreyColor,
    borderRadius: BorderRadius.circular(radius()),
  );
}
