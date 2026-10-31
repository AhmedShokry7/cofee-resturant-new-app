import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.isRead = true,
    this.onTap,
  });

  final NotificationModel notification;
  final bool isRead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
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
            _Lead(notification: notification),
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
                      if (!isRead)
                        Container(
                          height: 10.w,
                          width: 10.w,
                          margin: EdgeInsets.only(left: SpacingTokens.xs.w),
                          decoration: BoxDecoration(
                            color: AppColor.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      SizedBox(width: SpacingTokens.sm.w),
                      Text(
                        notification.time,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.body,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square at the head of the tile: the campaign picture when the message
/// carries one, the icon of its type otherwise.
///
/// The same square is kept in both cases, so a list of mixed rows stays on the
/// grid. [DbImage] answers a picture it cannot load with a neutral placeholder,
/// which is why a campaign without a usable image still reads as a message.
class _Lead extends StatelessWidget {
  const _Lead({required this.notification});

  final NotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final image = notification.imageUrl;
    final size = 44.w;
    if (image == null) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppColor.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          notification.icon,
          size: 22.w,
          color: AppColor.primaryColor,
        ),
      );
    }
    return DbImage(
      key: const ValueKey('notification-tile-image'),
      image: image,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(12.r),
      iconSize: 20.w,
    );
  }
}
