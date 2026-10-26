import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/data/models/admin_push_health.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class NotificationPushHealthPanel extends StatelessWidget {
  const NotificationPushHealthPanel({
    super.key,
    required this.health,
    required this.refreshing,
    required this.onRecheck,
    required this.onSetup,
  });

  final AdminPushHealth health;
  final bool refreshing;
  final VoidCallback onRecheck;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = notificationPushHealthStatus(health);
    final color = notificationPushHealthColor(status);
    final checks = notificationHealthChecks(health);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: Color(0x0A1B362B),
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final heading = Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: adminFlagBackground(
                        theme,
                        color,
                        notificationPushHealthSurface(status),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCloudServer,
                      size: 18,
                      color: adminFlagForeground(theme, color),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                S.notificationsPushHealthTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: adminHeadingColor(theme),
                                  fontSize: AppFontSizes.size12_5,
                                  fontWeight: AppFontWeights.bold,
                                  height: AppTextHeights.line1_5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusPill(status: status),
                          ],
                        ),
                        Text(
                          S.notificationsPushHealthSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    key: const Key('notification-health-recheck'),
                    onPressed: refreshing ? null : onRecheck,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: refreshing
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : HugeIcon(
                            icon: HugeIcons.strokeRoundedRefresh,
                            size: 14,
                            color: adminMutedColor(theme),
                          ),
                    label: Text(
                      S.notificationsPushRecheck,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('notification-health-setup'),
                    onPressed: onSetup,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedKey01,
                      size: 14,
                      color: AppColor.adminAccent,
                    ),
                    label: Text(
                      S.notificationsPushSetup,
                      style: const TextStyle(
                        color: AppColor.adminAccent,
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: actions,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 10),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 11),
          _CheckGrid(checks: checks),
          const SizedBox(height: 10),
          _StatsRow(health: health),
          if (status != NotificationPushHealthStatus.ready) ...[
            const SizedBox(height: 10),
            _ProblemList(health: health, status: status),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final NotificationPushHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notificationPushHealthColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          notificationPushHealthSurface(status),
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: adminIsDark(theme) ? .35 : .18),
        ),
      ),
      child: Text(
        notificationPushHealthLabel(status),
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

class _CheckGrid extends StatelessWidget {
  const _CheckGrid({required this.checks});

  final List<NotificationHealthCheck> checks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 520
            ? 2
            : width < 900
            ? 3
            : checks.length;
        const spacing = 8.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final check in checks)
              SizedBox(
                width: itemWidth,
                child: _CheckItem(check: check),
              ),
          ],
        );
      },
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.check});

  final NotificationHealthCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = check.ok ? AppColor.trendPositive : AppColor.trendNegative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: check.ok
                ? HugeIcons.strokeRoundedCheckmarkCircle01
                : HugeIcons.strokeRoundedCancelCircle,
            size: 14,
            color: adminFlagForeground(theme, color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  check.ok
                      ? S.notificationsPushCheckOk
                      : S.notificationsPushCheckMissing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminFlagForeground(theme, color),
                    fontSize: AppFontSizes.size8,
                    height: AppTextHeights.line1_4,
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.health});

  final AdminPushHealth health;

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[
      _Stat(
        icon: HugeIcons.strokeRoundedUserCheck01,
        label: S.notificationsPushReachable(health.reachableCustomers),
      ),
      _Stat(
        icon: HugeIcons.strokeRoundedNotification01,
        label: S.notificationsPushOptIn(health.pushEnabledCustomers),
      ),
      _Stat(
        icon: HugeIcons.strokeRoundedSmartPhone01,
        label: S.notificationsPushDevices(
          health.devicesAndroid,
          health.devicesIos,
        ),
      ),
      if (health.lastSuccessAt != null)
        _Stat(
          icon: HugeIcons.strokeRoundedSent,
          label: S.notificationsPushLastSuccess(
            notificationDateTimeLabel(health.lastSuccessAt),
          ),
        ),
      if (health.lastWebhookStatus != null)
        _Stat(
          icon: HugeIcons.strokeRoundedLink01,
          label: S.notificationsPushLastWebhook(
            localizeDigits('HTTP ${health.lastWebhookStatus}'),
          ),
        ),
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final stat in stats)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: stat.icon,
                size: 12,
                color: adminMutedColor(Theme.of(context)),
              ),
              const SizedBox(width: 4),
              Text(
                stat.label,
                style: TextStyle(
                  color: adminMutedColor(Theme.of(context)),
                  fontSize: AppFontSizes.size8_5,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Stat {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ProblemList extends StatelessWidget {
  const _ProblemList({required this.health, required this.status});

  final AdminPushHealth health;
  final NotificationPushHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = <String>[];
    if (!health.databaseReady) {
      final checks = notificationHealthChecks(health)
          .where((check) => !check.ok)
          .map((check) => check.label)
          .join(' • ');
      messages.add(
        checks.isEmpty
            ? S.notificationsPushFunctionHint
            : '${S.notificationsPushFunctionHint} ($checks)',
      );
      if (!health.webhookSecretConfigured) {
        messages.add(S.notificationsPushSecretHint);
      }
    } else {
      if (!health.hasReachableDevices) {
        messages.add(S.notificationsPushNoReachable);
      }
      final webhookStatus = health.lastWebhookStatus;
      if (webhookStatus != null &&
          (webhookStatus < 200 || webhookStatus >= 300)) {
        messages.add(S.notificationsPushHttpError(webhookStatus));
      }
      final webhookError = health.lastWebhookError;
      if (webhookError != null &&
          webhookError.isNotEmpty &&
          (webhookStatus == null ||
              webhookStatus < 200 ||
              webhookStatus >= 300)) {
        messages.add(webhookError);
      }
      final error = health.lastError;
      if (error != null && error.isNotEmpty) {
        messages.add('${S.notificationsPushLastError}: $error');
      }
    }
    if (messages.isEmpty) return const SizedBox.shrink();
    final color = status == NotificationPushHealthStatus.incomplete
        ? AppColor.trendNegative
        : AppColor.adminWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          notificationPushHealthSurface(status),
        ),
        borderRadius: BorderRadius.circular(8),
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
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: adminFlagForeground(theme, color),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
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
