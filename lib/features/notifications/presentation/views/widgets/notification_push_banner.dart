import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/widgets/notification_push_switch.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The one-tap offer to open the phone channel, above the list.
///
/// The page shows it only while the customer has never chosen: a device that
/// was asked and answered no is left alone, because asking again would call a
/// decision they already made a mistake. It is not shown before the switches
/// have been read, either - a silent phone is not the same as a refused one, and
/// a banner that flashes and then disappears reads as a bug.
///
/// The whole card is the target, so accepting is one tap, and the wording says
/// what will happen rather than promising that it worked: the system still has
/// a word to say, and [togglePushAndReport] reports it.
class NotificationPushBanner extends StatelessWidget {
  const NotificationPushBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = context.select<NotificationsCubit, bool>(
      (cubit) => cubit.state.pushEnabled,
    );
    final corner = BorderRadius.circular(AppRadius.r16);
    return Padding(
      key: const ValueKey('notification-push-banner'),
      padding: EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: S.turnOnNotifications,
        child: Material(
          color: AppColor.primarySoft,
          shape: RoundedRectangleBorder(borderRadius: corner),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => togglePushAndReport(context, enabled),
            borderRadius: corner,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    height: AppSizes.px32,
                    width: AppSizes.px32,
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.notificationOff,
                      size: AppSizes.px18,
                      color: AppColor.primaryColor,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.notificationPushPausedTitle,
                          style: AppFonts.semiBold14(context),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          S.notificationPushPausedHint,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.greyColor),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    S.turnOnNotifications,
                    style: AppFonts.semiBold14(context)
                        .copyWith(color: AppColor.primaryColor),
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
