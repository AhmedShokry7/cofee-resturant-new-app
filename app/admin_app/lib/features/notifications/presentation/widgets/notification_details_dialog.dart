import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_badges.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum NotificationDetailsAction { toggleRead, resend, delete }

Future<NotificationDetailsAction?> showNotificationDetailsDialog({
  required BuildContext context,
  required AdminNotification notification,
  required bool canSend,
  required bool canManage,
}) {
  return showDialog<NotificationDetailsAction>(
    context: context,
    builder: (_) => NotificationDetailsDialog(
      notification: notification,
      canSend: canSend,
      canManage: canManage,
    ),
  );
}

class NotificationDetailsDialog extends StatelessWidget {
  const NotificationDetailsDialog({
    super.key,
    required this.notification,
    required this.canSend,
    required this.canManage,
  });

  final AdminNotification notification;
  final bool canSend;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .88, 780.0);
    return Dialog(
      key: const Key('notification-details-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 700 ? AppDimensions.md : AppDimensions.xxl,
        vertical: AppDimensions.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: S.notificationsDetailsTitle,
                subtitle: S.notificationsDetailsSubtitle(
                  notificationCustomerName(notification),
                ),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppDimensions.lg,
                    AppDimensions.md,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Banner(notification: notification),
                      const SizedBox(height: 16),
                      _SectionLabel(label: S.notificationsDetailsContent),
                      const SizedBox(height: 7),
                      _LocalizedContent(notification: notification),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final customer = _CustomerCard(
                            notification: notification,
                          );
                          final source = _SourceCard(
                            notification: notification,
                          );
                          if (constraints.maxWidth < 620) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                customer,
                                const SizedBox(height: 10),
                                source,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: customer),
                              const SizedBox(width: 10),
                              Expanded(child: source),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _PushCard(notification: notification),
                      const SizedBox(height: 10),
                      _PayloadCard(notification: notification),
                      const SizedBox(height: 14),
                      _MetaLine(
                        label: S.notificationsDetailsCreated,
                        value: notificationDateTimeLabel(
                          notification.createdAt,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _MetaLine(
                        label: S.notificationsDetailsReadAt,
                        value: notification.readAt == null
                            ? S.notificationsDetailsNeverRead
                            : notificationDateTimeLabel(notification.readAt),
                      ),
                      if (notification.relatedEntityId != null) ...[
                        const SizedBox(height: 5),
                        _MetaLine(
                          label: S.notificationsDetailsRelated,
                          value: [
                            ?notificationRelatedLabel(
                              notification.relatedEntityType,
                            ),
                            notification.relatedEntityId!,
                          ].join(' • '),
                        ),
                      ],
                      if (canSend) ...[
                        const SizedBox(height: 12),
                        Text(
                          S.notificationsDetailsResendHint,
                          style: TextStyle(
                            color: adminMutedColor(Theme.of(context)),
                            fontSize: AppFontSizes.size9,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Footer(
                notification: notification,
                canSend: canSend,
                canManage: canManage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = notificationTypeColor(notification.type);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          typeColor,
          notificationTypeSurface(notification.type),
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: typeColor.withValues(alpha: adminIsDark(theme) ? .35 : .16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: notificationTypeIcon(notification.type),
              size: 20,
              color: adminFlagForeground(theme, typeColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationTitle(notification),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size14,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NotificationTypeBadge(type: notification.type),
                    NotificationReadBadge(isRead: notification.isRead),
                    NotificationPushBadge(state: notification.push.state),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          size: 12,
                          color: adminMutedColor(theme),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          notificationDateLabel(notification.createdAt),
                          style: TextStyle(
                            color: adminMutedColor(theme),
                            fontSize: AppFontSizes.size9,
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
        ],
      ),
    );
  }
}

class _LocalizedContent extends StatelessWidget {
  const _LocalizedContent({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final arabic = _LanguageBlock(
      label: S.notificationsDetailsArabic,
      title: notification.titleAr,
      body: notification.bodyAr,
      textDirection: TextDirection.rtl,
    );
    final english = _LanguageBlock(
      label: S.notificationsDetailsEnglish,
      title: notification.titleEn,
      body: notification.bodyEn,
      textDirection: TextDirection.ltr,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [arabic, const SizedBox(height: 9), english],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: arabic),
            const SizedBox(width: 9),
            Expanded(child: english),
          ],
        );
      },
    );
  }
}

class _LanguageBlock extends StatelessWidget {
  const _LanguageBlock({
    required this.label,
    required this.title,
    required this.body,
    required this.textDirection,
  });

  final String label;
  final String? title;
  final String? body;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size8_5,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_4,
                letterSpacing: AppLetterSpacings.space0_2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title ?? '—',
              style: TextStyle(
                color: title == null
                    ? adminMutedColor(theme)
                    : adminHeadingColor(theme),
                fontSize: AppFontSizes.size11_5,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body ?? '—',
              style: TextStyle(
                color: body == null
                    ? adminMutedColor(theme)
                    : adminBodyColor(theme),
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = notification.customer;
    return _InfoCard(
      title: S.notificationsDetailsCustomer,
      child: Row(
        children: [
          AdminAvatarImage(
            url: customer.avatarUrl,
            size: 40,
            fallbackText: notificationCustomerInitial(notification),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificationCustomerName(notification),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (customer.email != null)
                  Text(
                    customer.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                if (customer.phone != null)
                  Text(
                    customer.phone!,
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
    );
  }
}

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
          const SizedBox(height: 4),
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
            const SizedBox(height: 3),
            Text(
              notificationDateTimeLabel(campaign.createdAt),
              style: TextStyle(
                color: adminSubtleColor(theme),
                fontSize: AppFontSizes.size8_5,
                height: AppTextHeights.line1_4,
              ),
            ),
          ],
          if (campaign == null) ...[
            const SizedBox(height: 3),
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 6),
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
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: adminFlagBackground(
                  theme,
                  AppColor.trendNegative,
                  AppColor.trendNegativeSurface,
                ),
                borderRadius: BorderRadius.circular(7),
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
                  const SizedBox(height: 2),
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          color,
          Color.lerp(color, Colors.white, .86)!,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: adminFlagForeground(theme, color),
          fontSize: AppFontSizes.size8_5,
          fontWeight: AppFontWeights.semiBold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.notification});

  final AdminNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = notification.payload;
    final content = payload.isEmpty
        ? S.notificationsDetailsNoPayload
        : const JsonEncoder.withIndent('  ').convert(payload);
    return _InfoCard(
      title: S.notificationsDetailsPayload,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: adminTintedSurfaceColor(theme),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: adminRowBorderColor(theme)),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            content,
            style: TextStyle(
              color: payload.isEmpty
                  ? adminMutedColor(theme)
                  : adminBodyColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_6,
              fontFamily: payload.isEmpty ? null : 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(label: title),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        color: adminMutedColor(theme),
        fontSize: AppFontSizes.size8_5,
        fontWeight: AppFontWeights.semiBold,
        height: AppTextHeights.line1_4,
        letterSpacing: AppLetterSpacings.space0_2,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_4,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: adminSubtleColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.notification,
    required this.canSend,
    required this.canManage,
  });

  final AdminNotification notification;
  final bool canSend;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canManage)
            TextButton.icon(
              key: const Key('notification-details-delete'),
              onPressed: () =>
                  Navigator.of(context).pop(NotificationDetailsAction.delete),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                size: 15,
                color: AppColor.errorColor,
              ),
              label: Text(
                S.notificationsDelete,
                style: const TextStyle(
                  color: AppColor.errorColor,
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.close),
          ),
          if (canManage)
            OutlinedButton.icon(
              key: const Key('notification-details-toggle-read'),
              onPressed: () =>
                  Navigator.of(context)
                      .pop(NotificationDetailsAction.toggleRead),
              icon: HugeIcon(
                icon: notification.isRead
                    ? HugeIcons.strokeRoundedCircle
                    : HugeIcons.strokeRoundedCheckmarkCircle02,
                size: 15,
                color: adminBodyColor(theme),
              ),
              label: Text(
                notification.isRead
                    ? S.notificationsMarkUnread
                    : S.notificationsMarkRead,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          if (canSend)
            FilledButton.icon(
              key: const Key('notification-details-resend'),
              onPressed: () =>
                  Navigator.of(context).pop(NotificationDetailsAction.resend),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSent,
                size: 15,
                color: AppColor.whiteColor,
              ),
              label: Text(
                S.notificationsResend,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
