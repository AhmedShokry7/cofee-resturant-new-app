import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';

class BannerDots extends StatelessWidget {
  const BannerDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
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
