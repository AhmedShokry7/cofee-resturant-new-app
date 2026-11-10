import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_badges.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Future<void> showNotificationCampaignSummaryDialog({
  required BuildContext context,
  required AdminNotification notification,
}) => showDialog<void>(
  context: context,
  builder: (context) => _CampaignSummaryDialog(notification: notification),
);

class _CampaignSummaryDialog extends StatelessWidget {
  const _CampaignSummaryDialog({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final campaign = notification.campaign!;
    final push = notification.push;
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: screen.height * .86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: S.notificationsDetailsCampaign,
              subtitle: notificationAudienceLabel(campaign.audience),
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      notificationTitle(notification),
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size14,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.px4),
                    Text(
                      notificationExcerpt(notification) ?? '',
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size10,
                        height: AppTextHeights.line1_6,
                      ),
                    ),
                    if (notification.imageUrl != null) ...[
                      const SizedBox(height: AppSizes.px10),
                      AdminNetworkThumb(
                        imageUrl: notification.imageUrl!,
                        width: 180,
                        height: 92,
                      ),
                    ],
                    const SizedBox(height: AppSizes.px14),
                    _DetailBlock(
                      title: S.notificationsDetailsRecipients(
                        campaign.recipientCount,
                      ),
                      children: [
                        _DetailLine(
                          label: S.notificationsCampaignRead(campaign.readCount),
                        ),
                        _DetailLine(
                          label: S.notificationsCampaignUnread(
                            campaign.unreadCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.px10),
                    _DetailBlock(
                      title: S.notificationsDetailsPush,
                      children: [
                        NotificationPushBadge(state: push.state),
                        const SizedBox(height: AppSizes.px6),
                        _DetailLine(
                          label: S.notificationsDetailsDelivered(push.sent),
                          color: AppColor.trendPositive,
                        ),
                        if (push.failed > 0)
                          _DetailLine(
                            label: S.notificationsDetailsFailed(push.failed),
                            color: AppColor.trendNegative,
                          ),
                        if (push.invalidToken > 0)
                          _DetailLine(
                            label: S.notificationsDetailsInvalid(
                              push.invalidToken,
                            ),
                            color: AppColor.trendNegative,
                          ),
                        if (push.skipped > 0)
                          _DetailLine(
                            label: S.notificationsDetailsSkipped(push.skipped),
                            color: AppColor.adminWarning,
                          ),
                        if (push.lastError != null)
                          _DetailLine(label: push.lastError!),
                      ],
                    ),
                    const SizedBox(height: AppSizes.px10),
                    _DetailBlock(
                      title: S.notificationsDetailsEmail,
                      children: [
                        _DetailLine(
                          label: S.notificationsDetailsDelivered(
                            campaign.emailSent,
                          ),
                          color: AppColor.trendPositive,
                        ),
                        if (campaign.emailFailed > 0)
                          _DetailLine(
                            label: S.notificationsDetailsFailed(
                              campaign.emailFailed,
                            ),
                            color: AppColor.trendNegative,
                          ),
                        if (campaign.emailSkipped > 0)
                          _DetailLine(
                            label: S.notificationsDetailsSkipped(
                              campaign.emailSkipped,
                            ),
                            color: AppColor.adminWarning,
                          ),
                        if (campaign.emailSent +
                                campaign.emailFailed +
                                campaign.emailSkipped ==
                            0)
                          _DetailLine(label: S.notificationsDetailsNoAttempt),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: adminCardBorderColor(Theme.of(context))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: adminHeadingColor(Theme.of(context)),
            fontSize: AppFontSizes.size10_5,
            fontWeight: AppFontWeights.bold,
          ),
        ),
        const SizedBox(height: AppSizes.px6),
        ...children,
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Text(
      label,
      style: TextStyle(
        color: color ?? adminMutedColor(Theme.of(context)),
        fontSize: AppFontSizes.size9_5,
        height: AppTextHeights.line1_5,
      ),
    ),
  );
}
