import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class NotificationMetricsCards extends StatelessWidget {
  const NotificationMetricsCards({super.key, required this.metrics});

  final AdminNotificationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final unreadShare = metrics.total <= 0
        ? '0'
        : localizeDigits('${(metrics.unread * 100 / metrics.total).round()}');
    final rate = metrics.pushSuccessRate;
    final cards = <_MetricData>[
      _MetricData(
        label: S.notificationsMetricTotal,
        caption: localizeDigits(S.notificationsMetricTotalHint(metrics.today)),
        value: notificationCountValue(metrics.total),
        icon: AppIcons.notification01,
        iconBackground: AppColor.adminAccentSurface,
        iconColor: AppColor.adminAccent,
      ),
      _MetricData(
        label: S.notificationsMetricUnread,
        caption: S.notificationsMetricUnreadHint(unreadShare),
        value: notificationCountValue(metrics.unread),
        icon: AppIcons.eyeIcon,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.notificationsMetricAdminSent,
        caption: localizeDigits(
          S.notificationsMetricAdminSentHint(metrics.campaigns),
        ),
        value: notificationCountValue(metrics.adminSent),
        icon: AppIcons.sent,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.notificationsMetricPushRate,
        caption: rate == null
            ? S.notificationsMetricNoPush
            : localizeDigits(
                S.notificationsMetricPushHint(
                  metrics.pushSent,
                  metrics.pushFailed,
                ),
              ),
        value: notificationRateValue(rate),
        icon: AppIcons.smartPhone01,
        iconBackground: rate != null && rate < 90
            ? AppColor.trendNegativeSurface
            : AppColor.trendPositiveSurface,
        iconColor: rate != null && rate < 90
            ? AppColor.trendNegative
            : AppColor.trendPositive,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  caption: card.caption,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.caption,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String label;
  final String caption;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
}
