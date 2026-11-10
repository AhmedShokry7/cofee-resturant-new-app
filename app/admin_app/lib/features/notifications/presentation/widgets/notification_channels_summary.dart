import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_email_channel_panel.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_push_health_panel.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

class NotificationChannelsSummary extends StatelessWidget {
  const NotificationChannelsSummary({
    super.key,
    required this.metrics,
    required this.health,
    required this.refreshing,
    required this.onRecheck,
    required this.onSetup,
  });

  final AdminNotificationMetrics metrics;
  final AdminPushHealth health;
  final bool refreshing;
  final VoidCallback onRecheck;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppSizes.px10;
        final columns = constraints.maxWidth < 560 ? 1 : 2;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _ChannelTile(
                icon: AppIcons.smartPhone01,
                title: S.notificationsPushHealthTitle,
                status: notificationPushHealthLabel(
                  notificationPushHealthStatus(health),
                ),
                detail: S.notificationsPushReachable(
                  health.reachableCustomers,
                ),
                color: notificationPushHealthColor(
                  notificationPushHealthStatus(health),
                ),
                onTap: () => _showDetails(context),
              ),
            ),
            SizedBox(
              width: width,
              child: _ChannelTile(
                icon: AppIcons.email,
                title: S.notificationsEmailTitle,
                status: notificationEmailChannelLabel(
                  notificationEmailChannelStatus(metrics),
                ),
                detail: S.notificationsEmailReachable(metrics.emailableCustomers),
                color: notificationEmailChannelColor(
                  notificationEmailChannelStatus(metrics),
                ),
                onTap: () => _showDetails(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDetails(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Column(
          children: [
            AdminDialogHeader(
              title: S.notificationsChannelsTitle,
              subtitle: S.notificationsChannelsSubtitle,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    NotificationPushHealthPanel(
                      health: health,
                      refreshing: refreshing,
                      onRecheck: onRecheck,
                      onSetup: onSetup,
                    ),
                    const SizedBox(height: AppSizes.px12),
                    NotificationEmailChannelPanel(metrics: metrics),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 17, color: color),
              const SizedBox(width: AppSizes.px8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8_5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px8),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: AppFontSizes.size8_5,
                  fontWeight: AppFontWeights.bold,
                ),
              ),
              const SizedBox(width: AppSizes.px4),
              AppIcon(
                AppIcons.arrowRight01,
                size: 14,
                color: adminMutedColor(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
