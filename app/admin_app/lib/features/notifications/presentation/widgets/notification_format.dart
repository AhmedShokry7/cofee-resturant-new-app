import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';

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
  AdminNotificationType.orderStatus => AppIcons.shoppingBag01,
  AdminNotificationType.promo => AppIcons.promotion,
  AdminNotificationType.system => AppIcons.settings01,
  AdminNotificationType.loyalty => AppIcons.gift,
  AdminNotificationType.subscription => AppIcons.repeat,
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
  if (notification.campaign?.isSummary == true) {
    return localizeDigits(
      S.notificationsCampaignRecipients(notification.campaign!.recipientCount),
    );
  }
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
  if (notification.campaign?.isSummary == true) {
    final campaign = notification.campaign!;
    return localizeDigits(S.notificationsCampaignRead(campaign.readCount));
  }
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

String notificationDestinationLabel(
  AdminNotificationDestination destination,
) => switch (destination) {
  AdminNotificationDestination.none => _destinationCopy(
    '\u0627\u0644\u0635\u0641\u062d\u0629 \u0627\u0644\u0627\u0641\u062a\u0631\u0627\u0636\u064a\u0629 \u062d\u0633\u0628 \u0646\u0648\u0639 \u0627\u0644\u0625\u0634\u0639\u0627\u0631',
    'Use the default for the notification type',
  ),
  AdminNotificationDestination.home => _destinationCopy(
    '\u0627\u0644\u0635\u0641\u062d\u0629 \u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629',
    'Home',
  ),
  AdminNotificationDestination.categories => _destinationCopy(
    '\u0627\u0644\u062a\u0635\u0646\u064a\u0641\u0627\u062a',
    'Categories',
  ),
  AdminNotificationDestination.search => _destinationCopy(
    '\u0627\u0644\u0628\u062d\u062b',
    'Search',
  ),
  AdminNotificationDestination.cart => _destinationCopy(
    '\u0633\u0644\u0629 \u0627\u0644\u0645\u0634\u062a\u0631\u064a\u0627\u062a',
    'Cart',
  ),
  AdminNotificationDestination.favorites => _destinationCopy(
    '\u0627\u0644\u0645\u0641\u0636\u0644\u0629',
    'Favorites',
  ),
  AdminNotificationDestination.settings => _destinationCopy(
    '\u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a',
    'Settings',
  ),
  AdminNotificationDestination.offers => _destinationCopy(
    '\u0627\u0644\u0639\u0631\u0648\u0636 \u0648\u0627\u0644\u0643\u0648\u0628\u0648\u0646\u0627\u062a',
    'Offers and coupons',
  ),
  AdminNotificationDestination.orders => _destinationCopy(
    '\u0637\u0644\u0628\u0627\u062a\u064a',
    'My orders',
  ),
  AdminNotificationDestination.loyalty => _destinationCopy(
    '\u0627\u0644\u0648\u0644\u0627\u0621 \u0648\u0627\u0644\u0646\u0642\u0627\u0637',
    'Loyalty and points',
  ),
  AdminNotificationDestination.subscription => _destinationCopy(
    '\u0627\u0634\u062a\u0631\u0627\u0643\u064a',
    'My subscription',
  ),
  AdminNotificationDestination.notifications => _destinationCopy(
    '\u0625\u0634\u0639\u0627\u0631\u0627\u062a\u064a',
    'My notifications',
  ),
  AdminNotificationDestination.notificationSettings => _destinationCopy(
    '\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a',
    'Notification settings',
  ),
  AdminNotificationDestination.help => _destinationCopy(
    '\u0627\u0644\u0645\u0633\u0627\u0639\u062f\u0629',
    'Help center',
  ),
  AdminNotificationDestination.account => _destinationCopy(
    '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628',
    'Account details',
  ),
  AdminNotificationDestination.addresses => _destinationCopy(
    '\u0639\u0646\u0627\u0648\u064a\u0646\u064a',
    'My addresses',
  ),
};

String _destinationCopy(String arabic, String english) =>
    AppLocale.instance.isArabic ? arabic : english;

IconData notificationDestinationIcon(
  AdminNotificationDestination destination,
) => switch (destination) {
  AdminNotificationDestination.none => AppIcons.cancel01,
  AdminNotificationDestination.home => AppIcons.home01,
  AdminNotificationDestination.categories => AppIcons.gridView,
  AdminNotificationDestination.search => AppIcons.search01,
  AdminNotificationDestination.cart => AppIcons.shoppingCart01,
  AdminNotificationDestination.favorites => AppIcons.star,
  AdminNotificationDestination.settings => AppIcons.settings01,
  AdminNotificationDestination.offers => AppIcons.promotion,
  AdminNotificationDestination.orders => AppIcons.shoppingBag01,
  AdminNotificationDestination.loyalty => AppIcons.gift,
  AdminNotificationDestination.subscription => AppIcons.repeat,
  AdminNotificationDestination.notifications => AppIcons.notification01,
  AdminNotificationDestination.notificationSettings => AppIcons.settings01,
  AdminNotificationDestination.help => AppIcons.informationCircle,
  AdminNotificationDestination.account => AppIcons.user,
  AdminNotificationDestination.addresses => AppIcons.location01,
};

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
  if (!health.hasReachableDevices || webhookFailed || health.hasCurrentError) {
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

/// Where the mail channel stands, read only from what the database recorded.
///
/// A refusal outranks an empty audience: an address the provider rejected is
/// the more urgent of the two, and unlike push there is no device that can be
/// blamed for it.
enum NotificationEmailChannelStatus { blocked, noTarget, idle, ready }

NotificationEmailChannelStatus notificationEmailChannelStatus(
  AdminNotificationMetrics metrics,
) {
  if (metrics.emailSent == 0 && metrics.emailLastError != null) {
    return NotificationEmailChannelStatus.blocked;
  }
  if (metrics.emailableCustomers == 0) {
    return NotificationEmailChannelStatus.noTarget;
  }
  if (metrics.emailSent + metrics.emailFailed + metrics.emailSkipped == 0) {
    return NotificationEmailChannelStatus.idle;
  }
  return NotificationEmailChannelStatus.ready;
}

String notificationEmailChannelLabel(NotificationEmailChannelStatus status) =>
    switch (status) {
      NotificationEmailChannelStatus.blocked => S.notificationsEmailBlocked,
      NotificationEmailChannelStatus.noTarget => S.notificationsEmailNoTarget,
      NotificationEmailChannelStatus.idle => S.notificationsEmailIdle,
      NotificationEmailChannelStatus.ready => S.notificationsEmailReady,
    };

Color notificationEmailChannelColor(NotificationEmailChannelStatus status) =>
    switch (status) {
      NotificationEmailChannelStatus.blocked => AppColor.trendNegative,
      NotificationEmailChannelStatus.noTarget => AppColor.adminWarning,
      NotificationEmailChannelStatus.idle => AppColor.adminMuted,
      NotificationEmailChannelStatus.ready => AppColor.trendPositive,
    };

Color notificationEmailChannelSurface(NotificationEmailChannelStatus status) =>
    switch (status) {
      NotificationEmailChannelStatus.blocked => AppColor.trendNegativeSurface,
      NotificationEmailChannelStatus.noTarget => AppColor.adminWarningSurface,
      NotificationEmailChannelStatus.idle => AppColor.adminTableHeader,
      NotificationEmailChannelStatus.ready => AppColor.trendPositiveSurface,
    };
