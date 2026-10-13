import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    required this.onChanged,
    this.count = 5,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final value = index + 1;
        final isActive = value <= rating;
        return GestureDetector(
          onTap: () => onChanged(value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Icon(
              isActive ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 36.w,
              color: isActive ? AppColor.primaryColor : AppColor.borderColor,
            ),
          ),
        );
      }),
    );
  }
}
