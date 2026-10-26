import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum NotificationAction { details, toggleRead, resend, delete }

class NotificationActionsMenu extends StatelessWidget {
  const NotificationActionsMenu({
    super.key,
    required this.notification,
    required this.canSend,
    required this.canManage,
    required this.onAction,
  });

  final AdminNotification notification;
  final bool canSend;
  final bool canManage;
  final ValueChanged<NotificationAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return PopupMenuButton<NotificationAction>(
      key: Key('notification-menu-${notification.id}'),
      tooltip: S.notificationsMenuTooltip,
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem<NotificationAction>(
          value: NotificationAction.details,
          child: _item(
            theme,
            icon: HugeIcons.strokeRoundedEye,
            label: S.notificationsViewDetails,
            rtl: rtl,
          ),
        ),
        if (canManage)
          PopupMenuItem<NotificationAction>(
            value: NotificationAction.toggleRead,
            child: _item(
              theme,
              icon: notification.isRead
                  ? HugeIcons.strokeRoundedCircle
                  : HugeIcons.strokeRoundedCheckmarkCircle02,
              label: notification.isRead
                  ? S.notificationsMarkUnread
                  : S.notificationsMarkRead,
              rtl: rtl,
            ),
          ),
        if (canSend)
          PopupMenuItem<NotificationAction>(
            value: NotificationAction.resend,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedSent,
              label: S.notificationsResend,
              rtl: rtl,
            ),
          ),
        if (canManage) const PopupMenuDivider(),
        if (canManage)
          PopupMenuItem<NotificationAction>(
            value: NotificationAction.delete,
            child: _item(
              theme,
              icon: HugeIcons.strokeRoundedDelete02,
              label: S.notificationsDelete,
              rtl: rtl,
              color: AppColor.errorColor,
            ),
          ),
      ],
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedMoreHorizontal,
        size: 18,
        color: adminMutedColor(theme),
      ),
    );
  }

  Widget _item(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool rtl,
    Color? color,
  }) => Row(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    children: [
      HugeIcon(icon: icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: color ?? adminBodyColor(theme),
          fontSize: AppFontSizes.size11,
          height: AppTextHeights.line1_5,
        ),
      ),
    ],
  );
}
