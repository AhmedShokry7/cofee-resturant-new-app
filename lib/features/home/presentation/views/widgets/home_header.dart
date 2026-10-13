import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Good Morning",
                style: AppFonts.regular14(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
              SizedBox(height: 4.h),
              Text(
                "What would you like today?",
                style: AppFonts.semiBold20(context),
              ),
            ],
          ),
        ),
        SizedBox(width: SpacingTokens.sm.w),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).pushNamed(NotificationsPage.routeName),
          child: Container(
            height: 44.w,
            width: 44.w,
            decoration: BoxDecoration(
              color: AppColor.lightGreyColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              HugeIcons.strokeRoundedNotification01,
              size: 22.w,
              color: AppColor.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
