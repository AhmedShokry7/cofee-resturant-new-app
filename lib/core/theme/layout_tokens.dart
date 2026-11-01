import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';

/// The frame values a scrollable page shares with the skeleton that mirrors it.
///
/// They lived spelled out in the page and again in `shimmer.dart`, so a page
/// and its loading state could drift apart while the skeleton claimed to match.
class LayoutTokens {
  /// Padding around the body of a scrolling page: `lg` on the sides and at the
  /// bottom, a `md` gap under the app bar. The pages scale all four from the
  /// design width, which is what keeps a list flush with the cards inside it.
  static EdgeInsets pageBody() => EdgeInsets.fromLTRB(
    SpacingTokens.lg.w,
    SpacingTokens.md.h,
    SpacingTokens.lg.w,
    SpacingTokens.lg.w,
  );

  /// Corner radius of a content card, in design pixels.
  static const double cardRadius = 12;
}
