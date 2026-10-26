import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class NotificationTypeBadge extends StatelessWidget {
  const NotificationTypeBadge({super.key, required this.type});

  final AdminNotificationType type;

  @override
  Widget build(BuildContext context) => AdminStatusBadge(
    label: notificationTypeLabel(type),
    color: notificationTypeColor(type),
  );
}

class NotificationReadBadge extends StatelessWidget {
  const NotificationReadBadge({super.key, required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) => AdminStatusBadge(
    label: isRead ? S.notificationsRead : S.notificationsUnread,
    color: isRead ? AppColor.adminMuted : AppColor.adminWarning,
  );
}

class NotificationPushBadge extends StatelessWidget {
  const NotificationPushBadge({super.key, required this.state});

  final AdminNotificationPushState state;

  @override
  Widget build(BuildContext context) => AdminStatusBadge(
    label: notificationPushLabel(state),
    color: notificationPushColor(state),
  );
}

class NotificationAudienceBadge extends StatelessWidget {
  const NotificationAudienceBadge({super.key, required this.audience});

  final AdminNotificationAudience? audience;

  @override
  Widget build(BuildContext context) => AdminStatusBadge(
    label: notificationAudienceLabel(audience),
    color: AppColor.adminInfo,
  );
}

/// The small "Push ready" / "No push" chip of the customer picker.
class NotificationPushReadyChip extends StatelessWidget {
  const NotificationPushReadyChip({super.key, required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = ready ? AppColor.trendPositive : AppColor.adminMuted;
    final background = ready
        ? AppColor.trendPositiveSurface
        : AppColor.adminTableHeader;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, background),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: adminIsDark(theme) ? .35 : .18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: ready
                ? HugeIcons.strokeRoundedSmartPhone01
                : HugeIcons.strokeRoundedCancelCircle,
            size: 10,
            color: adminFlagForeground(theme, color),
          ),
          const SizedBox(width: 3),
          Text(
            ready
                ? S.notificationsComposePushReady
                : S.notificationsComposePushOff,
            style: TextStyle(
              color: adminFlagForeground(theme, color),
              fontSize: AppFontSizes.size8,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}
