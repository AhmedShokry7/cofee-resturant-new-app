part of 'notification_details_dialog.dart';

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campaign = notification.campaign;
    return _InfoCard(
      title: S.notificationsTableSource,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  notificationSourceLabel(notification),
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              if (campaign != null)
                NotificationAudienceBadge(audience: campaign.audience),
            ],
          ),
          const SizedBox(height: AppSizes.px4),
          Text(
            campaign != null
                ? S.notificationsDetailsRecipients(campaign.recipientCount)
                : S.notificationsDetailsAuto,
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_6,
            ),
          ),
          if (campaign != null && campaign.createdAt != null) ...[
            const SizedBox(height: AppSizes.px4),
            Text(
              notificationDateTimeLabel(campaign.createdAt),
              style: TextStyle(
                color: adminSubtleColor(theme),
                fontSize: AppFontSizes.size8_5,
                height: AppTextHeights.line1_4,
              ),
            ),
          ],
          if (campaign != null &&
              notification.destination !=
                  AdminNotificationDestination.none) ...[
            const SizedBox(height: AppSizes.px4),
            Text(
              '${S.notificationsComposeDestination}: '
              '${notificationDestinationLabel(notification.destination)}',
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_4,
              ),
            ),
          ],
          if (campaign != null && notification.imageUrl != null) ...[
            const SizedBox(height: AppSizes.px8),
            AdminNetworkThumb(
              key: const Key('notification-details-image'),
              imageUrl: notification.imageUrl,
              width: 132,
              height: 60,
              icon: notificationTypeIcon(notification.type),
            ),
          ],
          if (campaign == null) ...[
            const SizedBox(height: AppSizes.px4),
            Text(
              notificationSourceDetail(notification) ?? '—',
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PushCard extends StatelessWidget {
  const _PushCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final push = notification.push;
    return _InfoCard(
      title: S.notificationsDetailsPush,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NotificationPushBadge(state: push.state),
              const Spacer(),
              if (push.lastAt != null)
                Text(
                  S.notificationsDetailsLastAttempt(
                    notificationDateTimeLabel(push.lastAt),
                  ),
                  style: TextStyle(
                    color: adminSubtleColor(theme),
                    fontSize: AppFontSizes.size8_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
            ],
          ),
          if (push.hasAttempts) ...[
            const SizedBox(height: AppSizes.px8),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: [
                _CountChip(
                  label: S.notificationsDetailsDelivered(push.sent),
                  color: AppColor.trendPositive,
                ),
                if (push.failed > 0)
                  _CountChip(
                    label: S.notificationsDetailsFailed(push.failed),
                    color: AppColor.trendNegative,
                  ),
                if (push.invalidToken > 0)
                  _CountChip(
                    label: S.notificationsDetailsInvalid(push.invalidToken),
                    color: AppColor.trendNegative,
                  ),
                if (push.skipped > 0)
                  _CountChip(
                    label: S.notificationsDetailsSkipped(push.skipped),
                    color: AppColor.adminWarning,
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSizes.px6),
            Text(
              S.notificationsDetailsNoAttempt,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_6,
              ),
            ),
          ],
          if (push.lastError != null) ...[
            const SizedBox(height: AppSizes.px8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: adminFlagBackground(
                  theme,
                  AppColor.trendNegative,
                  AppColor.trendNegativeSurface,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.notificationsDetailsLastError,
                    style: TextStyle(
                      color: adminFlagForeground(theme, AppColor.trendNegative),
                      fontSize: AppFontSizes.size8_5,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                  const SizedBox(height: AppSizes.px2),
                  Text(
                    push.lastError!,
                    style: TextStyle(
                      color: adminFlagForeground(theme, AppColor.trendNegative),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
