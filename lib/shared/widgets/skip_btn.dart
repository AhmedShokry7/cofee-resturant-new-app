import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// The word that steps out of a flow, with its underline, pinned to the end of
/// the screen. `on_boarding`, sign-in and sign-up all offer it.
class SkipBtn extends StatelessWidget {
  const SkipBtn({super.key, required this.onTap});

  final void Function() onTap;

  /// The tappable box is capped, so the underline reads as a stroke under the
  /// word instead of a rule across the screen.
  static const double _maxWidth = 50;

  /// Gap between the label and its underline.
  static const double _underlineGap = 2;

  /// The underline is a hairline, so it scales with the screen instead of
  /// staying one device pixel on every one of them.
  static const double _underlineThickness = 1;

  @override
  Widget build(BuildContext context) {
    return Align(
      // Top-right: sign-in and sign-up drop this straight into a full-screen
      // Stack, where the corner is the only place it belongs.
      alignment: Alignment.topRight,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.skip,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
              SizedBox(height: _underlineGap),
              Container(
                height: _underlineThickness,
                width: double.infinity,
                color: AppColor.greyColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
