import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/data/models/admin_push_health.dart';

String notificationCountValue(int value) => localizeDigits(formatCount(value));

String notificationPercentValue(double value) =>
    localizeDigits('${value.round()}%');

String notificationRateValue(double? value) =>
    value == null ? '—' : localizeDigits('${value.toStringAsFixed(1)}%');

String notificationTypeLabel(AdminNotificationType type) => switch (type) {
  AdminNotificationType.orderStatus => S.notificationsTypeOrder,
  AdminNotificationType.promo => S.notificationsTypePromo,
  AdminNotificationType.system => S.notificationsTypeSystem,
  AdminNotificationType.loyalty => S.notificationsTypeLoyalty,
  AdminNotificationType.subscription => S.notificationsTypeSubscription,
};

IconData notificationTypeIcon(AdminNotificationType type) => switch (type) {
  AdminNotificationType.orderStatus => HugeIcons.strokeRoundedShoppingBag01,
  AdminNotificationType.promo => HugeIcons.strokeRoundedPromotion,
  AdminNotificationType.system => HugeIcons.strokeRoundedSettings01,
  AdminNotificationType.loyalty => HugeIcons.strokeRoundedGift,
  AdminNotificationType.subscription => HugeIcons.strokeRoundedRepeat,
};

Color notificationTypeColor(AdminNotificationType type) => switch (type) {
  AdminNotificationType.orderStatus => AppColor.adminInfo,
  AdminNotificationType.promo => AppColor.adminWarning,
  AdminNotificationType.system => AppColor.adminMuted,
  AdminNotificationType.loyalty => AppColor.adminAccent,
  AdminNotificationType.subscription => AppColor.trendPositive,
};

Color notificationTypeSurface(AdminNotificationType type) => switch (type) {
  AdminNotificationType.orderStatus => AppColor.adminInfoSurface,
  AdminNotificationType.promo => AppColor.adminWarningSurface,
  AdminNotificationType.system => AppColor.adminTableHeader,
  AdminNotificationType.loyalty => AppColor.adminAccentSurface,
  AdminNotificationType.subscription => AppColor.trendPositiveSurface,
};

String notificationPushLabel(AdminNotificationPushState state) =>
    switch (state) {
      AdminNotificationPushState.none => S.notificationsPushNone,
      AdminNotificationPushState.sent => S.notificationsPushSent,
      AdminNotificationPushState.failed => S.notificationsPushFailed,
      AdminNotificationPushState.skipped => S.notificationsPushSkipped,
    };

Color notificationPushColor(AdminNotificationPushState state) =>
    switch (state) {
      AdminNotificationPushState.sent => AppColor.trendPositive,
      AdminNotificationPushState.failed => AppColor.trendNegative,
      AdminNotificationPushState.skipped => AppColor.adminWarning,
      AdminNotificationPushState.none => AppColor.adminMuted,
    };

Color notificationPushSurface(AdminNotificationPushState state) =>
    switch (state) {
      AdminNotificationPushState.sent => AppColor.trendPositiveSurface,
      AdminNotificationPushState.failed => AppColor.trendNegativeSurface,
      AdminNotificationPushState.skipped => AppColor.adminWarningSurface,
      AdminNotificationPushState.none => AppColor.adminTableHeader,
    };

String notificationTitle(AdminNotification notification) {
  final language = AppLocale.instance.language;
  final title = notification.titleFor(language);
  if (title != null) return title;
  final body = notification.bodyFor(language);
  if (body != null) return body;
  return S.notificationsUntitled;
}

String? notificationExcerpt(AdminNotification notification) {
  final language = AppLocale.instance.language;
  final title = notification.titleFor(language);
  final body = notification.bodyFor(language);
  if (title == null || body == null || body == title) return null;
  return body;
}

String notificationCustomerName(AdminNotification notification) {
  final customer = notification.customer;
  final name = customer.fullName;
  if (name != null && name.isNotEmpty) return name;
  final email = customer.email;
  if (email != null && email.isNotEmpty) return email;
  final phone = customer.phone;
  if (phone != null && phone.isNotEmpty) return phone;
  return S.reviewsAnonymous;
}

String? notificationCustomerDetail(AdminNotification notification) {
  final customer = notification.customer;
  final name = customer.fullName;
  final email = customer.email;
  if (name == null || name.isEmpty) return customer.phone;
  if (email == null || email.isEmpty) return customer.phone;
  return email;
}

String? notificationCustomerInitial(AdminNotification notification) {
  final name = notificationCustomerName(notification).trim();
  if (name.isEmpty) return null;
  return name.substring(0, 1).toUpperCase();
}

String notificationAudienceLabel(AdminNotificationAudience? audience) =>
    switch (audience) {
      AdminNotificationAudience.all => S.notificationsAudienceAll,
      AdminNotificationAudience.pushEnabled =>
        S.notificationsAudiencePushEnabled,
      AdminNotificationAudience.hasDevice => S.notificationsAudienceHasDevice,
      AdminNotificationAudience.customer => S.notificationsAudienceCustomer,
      null => S.notificationsSourceCampaign,
    };

String notificationSourceLabel(AdminNotification notification) =>
    notification.isAdminSent
    ? S.notificationsSourceCampaign
    : S.notificationsSourceAutomatic;

String? notificationSourceDetail(AdminNotification notification) {
  final campaign = notification.campaign;
  if (campaign != null) return notificationAudienceLabel(campaign.audience);
  return notificationRelatedLabel(notification.relatedEntityType);
}

String? notificationRelatedLabel(String? type) => switch (type) {
  'order' => S.notificationsRelatedOrder,
  'loyalty' => S.notificationsRelatedLoyalty,
  'subscription' => S.notificationsRelatedSubscription,
  'system' => S.notificationsRelatedSystem,
  _ => null,
};

String notificationDateLabel(DateTime? value) => localizedDate(value);

String notificationTimeLabel(DateTime? value) =>
    value == null ? '—' : localizedTime(value.toLocal());

String notificationDateTimeLabel(DateTime? value) => localizedDateTime(value);

String notificationRowsLabel(int from, int to, int count) =>
    S.notificationsRowsLabel(from, to, count);

enum NotificationPushHealthStatus { ready, warning, incomplete }

NotificationPushHealthStatus notificationPushHealthStatus(
  AdminPushHealth health,
) {
  if (!health.databaseReady) return NotificationPushHealthStatus.incomplete;
  final webhookStatus = health.lastWebhookStatus;
  final webhookFailed =
      webhookStatus != null && (webhookStatus < 200 || webhookStatus >= 300);
  if (!health.hasReachableDevices ||
      webhookFailed ||
      health.lastError != null) {
    return NotificationPushHealthStatus.warning;
  }
  return NotificationPushHealthStatus.ready;
}

String notificationPushHealthLabel(NotificationPushHealthStatus status) =>
    switch (status) {
      NotificationPushHealthStatus.ready => S.notificationsPushHealthy,
      NotificationPushHealthStatus.warning => S.notificationsPushWarning,
      NotificationPushHealthStatus.incomplete => S.notificationsPushError,
    };

Color notificationPushHealthColor(NotificationPushHealthStatus status) =>
    switch (status) {
      NotificationPushHealthStatus.ready => AppColor.trendPositive,
      NotificationPushHealthStatus.warning => AppColor.adminWarning,
      NotificationPushHealthStatus.incomplete => AppColor.trendNegative,
    };

Color notificationPushHealthSurface(NotificationPushHealthStatus status) =>
    switch (status) {
      NotificationPushHealthStatus.ready => AppColor.trendPositiveSurface,
      NotificationPushHealthStatus.warning => AppColor.adminWarningSurface,
      NotificationPushHealthStatus.incomplete => AppColor.trendNegativeSurface,
    };

class NotificationHealthCheck {
  const NotificationHealthCheck({required this.label, required this.ok});

  final String label;
  final bool ok;
}

List<NotificationHealthCheck> notificationHealthChecks(
  AdminPushHealth health,
) => [
  NotificationHealthCheck(
    label: S.notificationsPushCheckVault,
    ok: health.vaultAvailable,
  ),
  NotificationHealthCheck(
    label: S.notificationsPushCheckSecret,
    ok: health.webhookSecretConfigured,
  ),
  NotificationHealthCheck(
    label: S.notificationsPushCheckPgNet,
    ok: health.pgNetInstalled,
  ),
  NotificationHealthCheck(
    label: S.notificationsPushCheckTrigger,
    ok: health.dispatchTriggerInstalled,
  ),
  NotificationHealthCheck(
    label: S.notificationsPushCheckUrl,
    ok: health.functionUrlConfigured,
  ),
];
