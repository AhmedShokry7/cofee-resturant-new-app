import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';

enum NotificationTypeFilter {
  all(null),
  orderStatus(AdminNotificationType.orderStatus),
  promo(AdminNotificationType.promo),
  system(AdminNotificationType.system),
  loyalty(AdminNotificationType.loyalty),
  subscription(AdminNotificationType.subscription);

  const NotificationTypeFilter(this.value);

  final AdminNotificationType? value;
}

enum NotificationReadFilter {
  all,
  unread,
  read;

  bool? get value => switch (this) {
    NotificationReadFilter.all => null,
    NotificationReadFilter.unread => false,
    NotificationReadFilter.read => true,
  };
}

enum NotificationPushFilter {
  all,
  sent,
  failed,
  skipped,
  none;

  String? get value => switch (this) {
    NotificationPushFilter.all => null,
    NotificationPushFilter.sent => 'sent',
    NotificationPushFilter.failed => 'failed',
    NotificationPushFilter.skipped => 'skipped',
    NotificationPushFilter.none => 'none',
  };
}

enum NotificationCampaignFilter {
  all(null),
  campaigns('campaign'),
  automatic('automatic');

  const NotificationCampaignFilter(this.value);

  final String? value;
}
