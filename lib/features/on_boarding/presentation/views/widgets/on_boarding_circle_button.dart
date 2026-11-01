import 'package:flutter/material.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/theme/app_color.dart';

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

  @override
  Widget build(BuildContext context) {
    final size = AppConstant.btnHeight(context) - 10;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: filled ? AppColor.primaryColor : null,
          border: filled
              ? null
              : Border.all(color: AppColor.primaryColor, width: 2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: AppConstant.btnIconSize(context),
          color: filled ? AppColor.whiteColor : AppColor.primaryColor,
        ),
      ),
    );
  }
}
