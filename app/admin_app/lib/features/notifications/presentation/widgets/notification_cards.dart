import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_actions_menu.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_badges.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class NotificationCards extends StatelessWidget {
  const NotificationCards({
    super.key,
    required this.notifications,
    required this.canSend,
    required this.canManage,
    required this.onOpen,
    required this.onAction,
  });

  final List<AdminNotification> notifications;
  final bool canSend;
  final bool canManage;
  final ValueChanged<AdminNotification> onOpen;
  final void Function(AdminNotification notification, NotificationAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px10),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationCard(
          key: Key('notification-card-${notification.id}'),
          notification: notification,
          canSend: canSend,
          canManage: canManage,
          onOpen: () => onOpen(notification),
          onAction: (action) => onAction(notification, action),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.canSend,
    required this.canManage,
    required this.onOpen,
    required this.onAction,
  });

  final AdminNotification notification;
  final bool canSend;
  final bool canManage;
  final VoidCallback onOpen;
  final ValueChanged<NotificationAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final excerpt = notificationExcerpt(notification);
    final initial = notificationCustomerInitial(notification);
    final typeColor = notificationTypeColor(notification.type);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminFlagBackground(
                        theme,
                        typeColor,
                        notificationTypeSurface(notification.type),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: AppIcon(
                      notificationTypeIcon(notification.type),
                      size: 17,
                      color: adminFlagForeground(theme, typeColor),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!notification.isRead) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColor.adminWarning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSizes.px6),
                            ],
                            Expanded(
                              child: Text(
                                notificationTitle(notification),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: adminHeadingColor(theme),
                                  fontSize: AppFontSizes.size11_5,
                                  fontWeight: AppFontWeights.bold,
                                  height: AppTextHeights.line1_5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.px2),
                        Row(
                          children: [
                            AdminAvatarImage(
                              url: notification.customer.avatarUrl,
                              size: 18,
                              fallbackText: initial,
                            ),
                            const SizedBox(width: AppSizes.px6),
                            Expanded(
                              child: Text(
                                notificationCustomerName(notification),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: adminMutedColor(theme),
                                  fontSize: AppFontSizes.size9,
                                  height: AppTextHeights.line1_4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.px6),
                  NotificationActionsMenu(
                    notification: notification,
                    canSend: canSend,
                    canManage: canManage,
                    onAction: onAction,
                  ),
                ],
              ),
              if (excerpt != null) ...[
                const SizedBox(height: AppSizes.px8),
                Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminSubtleColor(theme),
                    fontSize: AppFontSizes.size10,
                    height: AppTextHeights.line1_6,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.px10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  NotificationTypeBadge(type: notification.type),
                  NotificationReadBadge(isRead: notification.isRead),
                  NotificationPushBadge(state: notification.push.state),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.calendar03,
                        size: 11,
                        color: adminMutedColor(theme),
                      ),
                      const SizedBox(width: AppSizes.px4),
                      Text(
                        notificationDateLabel(notification.createdAt),
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size8_5,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
