import 'package:admin_app/features/notifications/domain/entities/notification_json.dart';

/// Everything the dashboard can verify about the push delivery path.
///
/// The page turns each flag into one checklist row, so an operator can see
/// whether the problem is in the database, the Edge Function, or the FCM
/// service account instead of guessing why a push never arrived.
class AdminPushHealth {
  const AdminPushHealth({
    this.vaultAvailable = false,
    this.webhookSecretConfigured = false,
    this.pgNetInstalled = false,
    this.dispatchTriggerInstalled = false,
    this.functionUrl,
    this.functionUrlConfigured = false,
    this.devicesTotal = 0,
    this.devicesAndroid = 0,
    this.devicesIos = 0,
    this.devicesWithLocale = 0,
    this.customersTotal = 0,
    this.pushEnabledCustomers = 0,
    this.reachableCustomers = 0,
    this.delivered30d = 0,
    this.failed30d = 0,
    this.skipped30d = 0,
    this.invalidToken30d = 0,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastError,
    this.lastErrorAt,
    this.lastWebhookStatus,
    this.lastWebhookError,
    this.lastWebhookAt,
  });

  final bool vaultAvailable;
  final bool webhookSecretConfigured;
  final bool pgNetInstalled;
  final bool dispatchTriggerInstalled;
  final String? functionUrl;
  final bool functionUrlConfigured;
  final int devicesTotal;
  final int devicesAndroid;
  final int devicesIos;
  final int devicesWithLocale;
  final int customersTotal;
  final int pushEnabledCustomers;
  final int reachableCustomers;
  final int delivered30d;
  final int failed30d;
  final int skipped30d;
  final int invalidToken30d;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastError;
  final DateTime? lastErrorAt;
  final int? lastWebhookStatus;
  final String? lastWebhookError;
  final DateTime? lastWebhookAt;

  /// True when the database side of the chain is fully configured.
  bool get databaseReady =>
      vaultAvailable &&
      webhookSecretConfigured &&
      pgNetInstalled &&
      dispatchTriggerInstalled &&
      functionUrlConfigured;

  /// True when at least one customer can actually receive a push.
  bool get hasReachableDevices => reachableCustomers > 0;

  factory AdminPushHealth.fromJson(Map<String, dynamic> json) {
    final deliveries = notificationMap(json['deliveries_30d']);
    return AdminPushHealth(
      vaultAvailable: json['vault_available'] == true,
      webhookSecretConfigured: json['webhook_secret_configured'] == true,
      pgNetInstalled: json['pg_net_installed'] == true,
      dispatchTriggerInstalled: json['dispatch_trigger_installed'] == true,
      functionUrl: notificationText(json['function_url']),
      functionUrlConfigured: json['function_url_configured'] == true,
      devicesTotal: notificationInt(json['devices_total']),
      devicesAndroid: notificationInt(json['devices_android']),
      devicesIos: notificationInt(json['devices_ios']),
      devicesWithLocale: notificationInt(json['devices_with_locale']),
      customersTotal: notificationInt(json['customers_total']),
      pushEnabledCustomers: notificationInt(json['push_enabled_customers']),
      reachableCustomers: notificationInt(json['reachable_customers']),
      delivered30d: notificationInt(deliveries?['sent']),
      failed30d: notificationInt(deliveries?['failed']),
      skipped30d: notificationInt(deliveries?['skipped']),
      invalidToken30d: notificationInt(deliveries?['invalid_token']),
      lastSuccessAt: notificationDate(json['last_success_at']),
      lastFailureAt: notificationDate(json['last_failure_at']),
      lastError: notificationText(json['last_error']),
      lastErrorAt: notificationDate(json['last_error_at']),
      lastWebhookStatus: json['last_webhook_status'] == null
          ? null
          : notificationInt(json['last_webhook_status']),
      lastWebhookError: notificationText(json['last_webhook_error']),
      lastWebhookAt: notificationDate(json['last_webhook_at']),
    );
  }
}
