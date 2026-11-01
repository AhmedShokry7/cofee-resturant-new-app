import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The round step control both onboarding buttons are built from.
class OnBoardingCircleButton extends StatelessWidget {
  const OnBoardingCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Filled marks the forward step, outlined the backward one.
  final bool filled;

  /// A step is the row's button height minus this inset, so the circles do not
  /// meet the edges of the screen.
  static const double _inset = AppSizes.px10;

  /// The outline the backward step is drawn with.
  static const double _outlineWidth = AppSizes.px2;

  /// The width a step occupies, so a screen holding a step on one side can
  /// reserve exactly that much on the other.
  static const double stepSize = AppDimensions.buttonHeight - _inset;

  @override
  Widget build(BuildContext context) {
    final size = stepSize;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: filled ? AppColor.primaryColor : null,
          border: filled
              ? null
              : Border.all(color: AppColor.primaryColor, width: _outlineWidth),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: AppIconSize.xl,
          color: filled ? AppColor.whiteColor : AppColor.primaryColor,
        ),
      ),
    );
  }
}
