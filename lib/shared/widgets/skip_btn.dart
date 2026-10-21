import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

class SkipBtn extends StatelessWidget {
  final void Function() onTap;
  const SkipBtn({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(maxWidth: 50.h),
            child: Column(
              children: [
                Text(
                  S.skip,
                  style: AppFonts.regular14(context).copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  height: 1,
                  width: 100.h,
                  decoration: const BoxDecoration(color: AppColor.greyColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
