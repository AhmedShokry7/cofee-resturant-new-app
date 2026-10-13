import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44.w,
            width: 44.w,
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              notification.icon,
              size: 22.w,
              color: AppColor.primaryColor,
            ),
          ),
          SizedBox(width: SpacingTokens.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppFonts.semiBold16(context),
                      ),
                    ),
                    SizedBox(width: SpacingTokens.sm.w),
                    Text(
                      notification.time,
                      style: AppFonts.regular12(
                        context,
                      ).copyWith(color: AppColor.greyColor),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  notification.body,
                  style: AppFonts.regular14(
                    context,
                  ).copyWith(color: AppColor.greyColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
