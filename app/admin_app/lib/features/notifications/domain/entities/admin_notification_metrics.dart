import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/notification_json.dart';

class AdminNotificationMetrics {
  const AdminNotificationMetrics({
    this.total = 0,
    this.unread = 0,
    this.today = 0,
    this.thisMonth = 0,
    this.adminSent = 0,
    this.adminSentMonth = 0,
    this.campaigns = 0,
    this.customersTotal = 0,
    this.pushEnabledCustomers = 0,
    this.reachableCustomers = 0,
    this.devicesTotal = 0,
    this.pushSent = 0,
    this.pushFailed = 0,
    this.pushSkipped = 0,
    this.pushInvalidToken = 0,
    this.pushSuccessRate,
    this.emailEnabledCustomers = 0,
    this.emailableCustomers = 0,
    this.emailSent = 0,
    this.emailFailed = 0,
    this.emailSkipped = 0,
    this.emailLastError,
    this.emailSuccessRate,
    this.byType = const <AdminNotificationType, int>{},
  });

  final int total;
  final int unread;
  final int today;
  final int thisMonth;
  final int adminSent;
  final int adminSentMonth;
  final int campaigns;
  final int customersTotal;
  final int pushEnabledCustomers;
  final int reachableCustomers;
  final int devicesTotal;
  final int pushSent;
  final int pushFailed;
  final int pushSkipped;
  final int pushInvalidToken;

  /// The share of push attempts that were delivered in the last 30 days,
  /// between 0 and 100, or null when nothing was attempted.
  final double? pushSuccessRate;

  /// Customers who opted in to the mail channel, whether or not they have an
  /// address on file.
  final int emailEnabledCustomers;

  /// Customers the panel can actually mail: opted in and holding an address.
  final int emailableCustomers;
  final int emailSent;
  final int emailFailed;
  final int emailSkipped;

  /// The provider's own words about the last failed delivery, or null when no
  /// delivery has failed. It is what tells the admin why nothing arrived.
  final String? emailLastError;

  /// The share of mail attempts that reached the provider in the last 30 days,
  /// between 0 and 100, or null when nothing was attempted.
  final double? emailSuccessRate;

  final Map<AdminNotificationType, int> byType;

  static const empty = AdminNotificationMetrics();

  int countFor(AdminNotificationType type) => byType[type] ?? 0;

  factory AdminNotificationMetrics.fromJson(Map<String, dynamic> json) {
    final rawByType = notificationMap(json['by_type']);
    final rawPush = notificationMap(json['push']);
    final rawEmail = notificationMap(json['email']);
    final byType = <AdminNotificationType, int>{
      for (final type in AdminNotificationType.values)
        type: notificationInt(rawByType?[type.value]),
    };
    return AdminNotificationMetrics(
      total: notificationInt(json['total']),
      unread: notificationInt(json['unread']),
      today: notificationInt(json['today']),
      thisMonth: notificationInt(json['this_month']),
      adminSent: notificationInt(json['admin_sent']),
      adminSentMonth: notificationInt(json['admin_sent_month']),
      campaigns: notificationInt(json['campaigns']),
      customersTotal: notificationInt(json['customers_total']),
      pushEnabledCustomers: notificationInt(json['push_enabled_customers']),
      reachableCustomers: notificationInt(json['reachable_customers']),
      devicesTotal: notificationInt(json['devices_total']),
      pushSent: notificationInt(rawPush?['sent']),
      pushFailed: notificationInt(rawPush?['failed']),
      pushSkipped: notificationInt(rawPush?['skipped']),
      pushInvalidToken: notificationInt(rawPush?['invalid_token']),
      pushSuccessRate: json['push_success_rate'] == null
          ? null
          : notificationDouble(json['push_success_rate']),
      emailEnabledCustomers: notificationInt(json['email_enabled_customers']),
      emailableCustomers: notificationInt(json['emailable_customers']),
      emailSent: notificationInt(rawEmail?['sent']),
      emailFailed: notificationInt(rawEmail?['failed']),
      emailSkipped: notificationInt(rawEmail?['skipped']),
      emailLastError: notificationText(rawEmail?['last_error']),
      emailSuccessRate: json['email_success_rate'] == null
          ? null
          : notificationDouble(json['email_success_rate']),
      byType: Map<AdminNotificationType, int>.unmodifiable(byType),
    );
  }
}
