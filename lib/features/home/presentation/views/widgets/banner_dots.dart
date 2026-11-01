import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class BannerDots extends StatelessWidget {
  const BannerDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  /// The dot for the banner being shown, and for the others.
  static const double _activeSize = 10;
  static const double _idleSize = 8;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: MotionTokens.dotMorph,
          curve: MotionTokens.entranceCurve,
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          height: (isActive ? _activeSize : _idleSize),
          width: (isActive ? _activeSize : _idleSize),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColor.primaryColor : AppColor.borderColor,
          ),
        );
      }),
    );
  }
}
