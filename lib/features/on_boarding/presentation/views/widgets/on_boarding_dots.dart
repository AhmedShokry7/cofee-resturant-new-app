import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';

/// One dot per slide, the current one larger and in the brand colour.
class OnBoardingDots extends StatelessWidget {
  const OnBoardingDots({
    super.key,
    required this.currentPage,
    required this.slideCount,
  });

  /// The slide this dot stands for, zero based.
  final int currentPage;

  /// How many slides there are.
  final int slideCount;

  static const double _activeSize = 10;
  static const double _idleSize = 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(
          slideCount,
          (index) {
            final isActive = index == currentPage;
            return AnimatedContainer(
              margin: EdgeInsets.only(right: SpacingTokens.sm.w),
              height: (isActive ? _activeSize : _idleSize).h,
              width: (isActive ? _activeSize : _idleSize).h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColor.primaryColor
                    : AppColor.greyColor.withValues(alpha: .5),
              ),
              duration: MotionTokens.dotMorph,
              curve: MotionTokens.entranceCurve,
            );
          },
        ),
      ],
    );
  }
}
