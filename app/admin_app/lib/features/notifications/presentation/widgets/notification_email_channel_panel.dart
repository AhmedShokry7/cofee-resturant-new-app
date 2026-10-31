import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// The mail channel of the notifications screen.
///
/// Push and mail are two separate promises to the customer, so the panel keeps
/// them in two separate cards. Nothing here is inferred: every line is a row
/// the database wrote when it tried to mail someone, and the provider's own
/// words are printed when it refused.
class NotificationEmailChannelPanel extends StatelessWidget {
  const NotificationEmailChannelPanel({super.key, required this.metrics});

  final AdminNotificationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = notificationEmailChannelStatus(metrics);
    final color = notificationEmailChannelColor(status);
    return AdminSectionCard(
      key: const Key('notification-email-channel'),
      title: S.notificationsEmailTitle,
      subtitle: S.notificationsEmailSubtitle,
      leading: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: adminFlagBackground(
            theme,
            color,
            notificationEmailChannelSurface(status),
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: AppIcon(
          AppIcons.email,
          size: 18,
          color: adminFlagForeground(theme, color),
        ),
      ),
      trailing: _StatusPill(status: status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatsRow(metrics: metrics),
          ..._problems(status),
        ],
      ),
    );
  }

  List<Widget> _problems(NotificationEmailChannelStatus status) {
    final error = metrics.emailLastError;
    final attempts =
        metrics.emailSent + metrics.emailFailed + metrics.emailSkipped;
    final messages = <String>[
      if (error != null) S.notificationsEmailRefused(error),
      if (metrics.emailableCustomers == 0) S.notificationsEmailNoTargetHint,
      if (attempts == 0) S.notificationsEmailNoAttempts,
    ];
    if (messages.isEmpty) return const [];
    return [
      const SizedBox(height: AppSizes.px10),
      _ProblemList(messages: messages, status: status),
    ];
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final NotificationEmailChannelStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notificationEmailChannelColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          notificationEmailChannelSurface(status),
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: color.withValues(alpha: adminIsDark(theme) ? .35 : .18),
        ),
      ),
      child: Text(
        notificationEmailChannelLabel(status),
        style: TextStyle(
          color: adminFlagForeground(theme, color),
          fontSize: AppFontSizes.size8_5,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.metrics});

  final AdminNotificationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = adminMutedColor(theme);
    final stats = <_Stat>[
      _Stat(
        icon: AppIcons.userCheck01,
        label: localizeDigits(
          S.notificationsEmailOptIn(metrics.emailEnabledCustomers),
        ),
      ),
      _Stat(
        icon: AppIcons.email,
        label: localizeDigits(
          S.notificationsEmailReachable(metrics.emailableCustomers),
        ),
      ),
      if (metrics.emailSuccessRate != null)
        _Stat(
          icon: AppIcons.sent,
          label: localizeDigits(
            S.notificationsEmailRate(
              metrics.emailSuccessRate!.toStringAsFixed(1),
            ),
          ),
        ),
      _Stat(
        icon: AppIcons.clock01,
        label: localizeDigits(
          S.notificationsEmailAttempts(
            metrics.emailSent,
            metrics.emailFailed,
            metrics.emailSkipped,
          ),
        ),
      ),
    ];
    // Wrap gives its children an unbounded main axis, so a counter line would
    // print past the card on a phone unless the run width bounds it first.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final stat in stats)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(stat.icon, size: 12, color: muted),
                    const SizedBox(width: AppSizes.px4),
                    Flexible(
                      child: Text(
                        stat.label,
                        style: TextStyle(
                          color: muted,
                          fontSize: AppFontSizes.size8_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stat {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ProblemList extends StatelessWidget {
  const _ProblemList({required this.messages, required this.status});

  final List<String> messages;
  final NotificationEmailChannelStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notificationEmailChannelColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          notificationEmailChannelSurface(status),
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withValues(alpha: adminIsDark(theme) ? .35 : .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < messages.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: adminFlagForeground(theme, color),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px6),
                  Expanded(
                    child: Text(
                      messages[index],
                      style: TextStyle(
                        color: adminFlagForeground(theme, color),
                        fontSize: AppFontSizes.size9,
                        height: AppTextHeights.line1_6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
