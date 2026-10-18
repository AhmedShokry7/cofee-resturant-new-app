import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';

class BannerDots extends StatelessWidget {
  const BannerDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  /// Must finish before the slide does, otherwise the dots are still moving
  /// when the new banner has already arrived and the two look out of step.
  static const _transition = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: _transition,
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.symmetric(horizontal: SpacingTokens.xs.w),
          height: isActive ? 10.w : 8.w,
          width: isActive ? 10.w : 8.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColor.primaryColor : AppColor.borderColor,
          ),
        );
      }),
    );
  }
}

