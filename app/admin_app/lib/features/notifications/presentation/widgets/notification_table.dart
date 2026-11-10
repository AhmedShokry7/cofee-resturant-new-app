import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_actions_menu.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_badges.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class NotificationTable extends StatelessWidget {
  const NotificationTable({
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

  static const _minWidth = 1180.0;
  static const _customerWidth = 170.0;
  static const _typeWidth = 96.0;
  static const _sourceWidth = 132.0;
  static const _dateWidth = 100.0;
  static const _readWidth = 88.0;
  static const _pushWidth = 92.0;
  static const _actionWidth = 36.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math
          .min(math.max(constraints.maxWidth, _minWidth), 1760)
          .toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Header(),
              for (final notification in notifications)
                _Row(
                  key: Key('notification-row-${notification.id}'),
                  notification: notification,
                  canSend: canSend,
                  canManage: canManage,
                  onOpen: () => onOpen(notification),
                  onAction: (action) => onAction(notification, action),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: dark ? AppColor.darkSurfaceContainer : AppColor.adminTableHeader,
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.adminTableBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _cell(S.notificationsTableNotification, dark)),
          SizedBox(
            width: NotificationTable._customerWidth,
            child: _cell(S.notificationsTableCustomer, dark),
          ),
          SizedBox(
            width: NotificationTable._typeWidth,
            child: _cell(S.notificationsTableType, dark),
          ),
          SizedBox(
            width: NotificationTable._sourceWidth,
            child: _cell(S.notificationsTableSource, dark),
          ),
          SizedBox(
            width: NotificationTable._dateWidth,
            child: _cell(S.notificationsTableDate, dark),
          ),
          SizedBox(
            width: NotificationTable._readWidth,
            child: _cell(S.notificationsTableRead, dark),
          ),
          SizedBox(
            width: NotificationTable._pushWidth,
            child: _cell(S.notificationsTablePush, dark),
          ),
          const SizedBox(width: NotificationTable._actionWidth),
        ],
      ),
    );
  }

  Widget _cell(String label, bool dark) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.medium,
      height: AppTextHeights.line1_5,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
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
      color: AppColor.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: adminRowBorderColor(theme)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
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
                        mainAxisAlignment: MainAxisAlignment.center,
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
                                    color: adminBodyColor(theme),
                                    fontSize: AppFontSizes.size11_5,
                                    fontWeight: AppFontWeights.bold,
                                    height: AppTextHeights.line1_5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (excerpt != null) ...[
                            const SizedBox(height: AppSizes.px1),
                            Text(
                              excerpt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: adminSubtleColor(theme),
                                fontSize: AppFontSizes.size9,
                                height: AppTextHeights.line1_4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: NotificationTable._customerWidth,
                child: Row(
                  children: [
                    AdminAvatarImage(
                      url: notification.customer.avatarUrl,
                      size: 28,
                      fallbackText: initial,
                    ),
                    const SizedBox(width: AppSizes.px8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notificationCustomerName(notification),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size10_5,
                              fontWeight: AppFontWeights.semiBold,
                              height: AppTextHeights.line1_5,
                            ),
                          ),
                          Text(
                            notificationCustomerDetail(notification) ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: adminSubtleColor(theme),
                              fontSize: AppFontSizes.size8_5,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: NotificationTable._typeWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: NotificationTypeBadge(type: notification.type),
                ),
              ),
              SizedBox(
                width: NotificationTable._sourceWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificationSourceLabel(notification),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      notificationSourceDetail(notification) ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: NotificationTable._dateWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificationDateLabel(notification.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      notificationTimeLabel(notification.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: NotificationTable._readWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: NotificationReadBadge(isRead: notification.isRead),
                ),
              ),
              SizedBox(
                width: NotificationTable._pushWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: NotificationPushBadge(state: notification.push.state),
                ),
              ),
              SizedBox(
                width: NotificationTable._actionWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: NotificationActionsMenu(
                    notification: notification,
                    canSend: canSend,
                    canManage: canManage,
                    onAction: onAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
