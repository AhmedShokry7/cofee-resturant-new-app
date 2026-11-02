import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// The word that steps out of a flow - and the one place it is put on screen.
///
/// The intro slides, sign-in and sign-up all offer it, and all three get the
/// same control from the same widget: pinned to the top corner nearest the end
/// of the reading direction (top-right in Arabic, top-left in English), inset by
/// [AppDimensions.skipInset] from both edges, inside the safe area of the window
/// it is drawn in. A screen adds it as the last child of its `Stack` and never
/// places it again; it is never put inside a scroll view, because a control that
/// leaves the screen when the form grows is no longer a way out.
///
/// The underline is drawn by the text engine, so it is exactly as wide as the
/// word - it reads as a struck label, not as a rule across the screen.
class SkipBtn extends StatelessWidget {
  const SkipBtn({super.key, required this.onTap});

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: AppDimensions.skipInset,
          end: AppDimensions.skipInset,
        ),
        child: TextButton(
          onPressed: onTap,
          // The box is the accessibility floor the app already promises, so the
          // word's own width never decides how hard the control is to hit.
          style: TextButton.styleFrom(
            minimumSize: Size.square(AppDimensions.tapTargetMin),
          ),
          child: Text(
            S.skip,
            style: AppFonts.medium14(context).copyWith(
              color: AppColor.greyColor,
              height: AppTextHeights.tight,
              decoration: TextDecoration.underline,
              decorationColor: AppColor.greyColor,
            ),
          ),
        ),
      ),
    );
  }
}
