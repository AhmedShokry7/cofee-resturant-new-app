import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// One message of the list: what it says, how strongly it reads, where it goes.
///
/// The row decides nothing by itself - [onTap] comes from the page, which asks
/// the cubit for the destination and marks the row seen.
///
/// An unread row is drawn on the 6% brand tint the selected rows already use,
/// ringed with the brand ring token, so the part of the list still waiting for
/// the customer is legible without relying on the small dot alone.
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
    final corner = BorderRadius.circular(AppRadius.r16);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        child: Material(
          color: isRead ? AppColor.cardSurface : AppColor.primarySoft,
          shape: RoundedRectangleBorder(
            borderRadius: corner,
            side: BorderSide(
              color: isRead ? AppColor.borderColor : AppColor.primaryRing,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: corner,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Lead(notification: notification),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: isRead
                                    ? AppFonts.semiBold16(context)
                                    : AppFonts.bold16(context),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                height: AppSizes.px10,
                                width: AppSizes.px10,
                                margin: EdgeInsetsDirectional.only(
                                  start: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColor.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            SizedBox(width: AppSpacing.sm),
                            Text(
                              notification.time,
                              style: AppFonts.regular12(context)
                                  .copyWith(color: AppColor.greyColor),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
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
          ),
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
    final size = AppSizes.px44;
    if (image == null) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: AppColor.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
        child: Icon(
          notification.icon,
          size: AppSizes.px22,
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
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      iconSize: AppSizes.px20,
    );
  }
}
