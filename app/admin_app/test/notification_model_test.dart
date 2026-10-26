import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification.dart';
import 'package:admin_app/features/notifications/data/models/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/data/models/admin_push_health.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';

AdminNotification _notification({
  AdminNotificationType type = AdminNotificationType.promo,
  AdminNotificationCustomer customer = const AdminNotificationCustomer(
    id: 'u1',
    fullName: 'Mona',
    email: 'mona@example.com',
  ),
  AdminNotificationPush push = const AdminNotificationPush(
    state: AdminNotificationPushState.sent,
    total: 1,
    sent: 1,
  ),
  String? titleAr,
  String? titleEn,
  String? bodyAr,
  String? bodyEn,
  String? relatedType,
  AdminNotificationCampaign? campaign,
}) => AdminNotification(
  id: 'n1',
  type: type,
  customer: customer,
  push: push,
  titleAr: titleAr,
  titleEn: titleEn,
  bodyAr: bodyAr,
  bodyEn: bodyEn,
  relatedEntityType: relatedType,
  campaign: campaign,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('notification json', () {
    test('a full row maps the customer, campaign and push', () {
      final notification = AdminNotification.fromJson(<String, dynamic>{
        'id': 'n9',
        'type': 'promo',
        'title_ar': 'خصم اليوم',
        'title_en': 'Today only',
        'body_ar': 'خصم ٢٠٪ على كل القهوة',
        'body_en': '20% off every coffee',
        'payload': {'screen': 'offers', 'id': 7},
        'related_entity_type': 'order',
        'related_entity_id': 'o1',
        'is_read': true,
        'read_at': '2026-10-02T08:00:00Z',
        'created_at': '2026-10-01T09:30:00Z',
        'customer': {
          'id': 'u1',
          'full_name': 'Mona',
          'email': 'mona@example.com',
          'phone': '+201000000000',
          'avatar_url': 'https://example.com/avatar.png',
        },
        'campaign': {
          'id': 'c1',
          'audience': 'push_enabled',
          'recipient_count': 14,
          'created_at': '2026-10-01T09:29:00Z',
        },
        'push': {
          'state': 'sent',
          'total': 14,
          'sent': 12,
          'failed': 1,
          'invalid_token': 1,
          'skipped': 0,
          'last_at': '2026-10-01T09:31:00Z',
        },
      });

      expect(notification.id, 'n9');
      expect(notification.type, AdminNotificationType.promo);
      expect(notification.customer.fullName, 'Mona');
      expect(notification.customer.phone, '+201000000000');
      expect(notification.payload['screen'], 'offers');
      expect(notification.payload['id'], 7);
      expect(notification.relatedEntityType, 'order');
      expect(notification.relatedEntityId, 'o1');
      expect(notification.isRead, isTrue);
      expect(notification.readAt?.toUtc(), DateTime.utc(2026, 10, 2, 8));
      expect(notification.createdAt?.toUtc(), DateTime.utc(2026, 10, 1, 9, 30));
      expect(notification.campaign?.id, 'c1');
      expect(
        notification.campaign?.audience,
        AdminNotificationAudience.pushEnabled,
      );
      expect(notification.campaign?.recipientCount, 14);
      expect(notification.isAdminSent, isTrue);
      expect(notification.push.state, AdminNotificationPushState.sent);
      expect(notification.push.total, 14);
      expect(notification.push.sent, 12);
      expect(notification.push.failed, 1);
      expect(notification.push.invalidToken, 1);
      expect(
        notification.push.lastAt?.toUtc(),
        DateTime.utc(2026, 10, 1, 9, 31),
      );
      expect(notification.push.hasAttempts, isTrue);
    });

    test('missing relations fall back to safe defaults', () {
      final notification = AdminNotification.fromJson(<String, dynamic>{
        'id': 'n2',
        'type': 'unsupported',
      });

      expect(notification.type, AdminNotificationType.system);
      expect(notification.customer.id, '');
      expect(notification.campaign, isNull);
      expect(notification.isAdminSent, isFalse);
      expect(notification.push.state, AdminNotificationPushState.none);
      expect(notification.push.hasAttempts, isFalse);
      expect(notification.isRead, isFalse);
      expect(notification.payload, isEmpty);
    });

    test('an unknown campaign audience is ignored', () {
      final notification = AdminNotification.fromJson(<String, dynamic>{
        'id': 'n3',
        'type': 'promo',
        'campaign': {'id': 'c3', 'audience': 'friends'},
      });

      expect(notification.campaign?.id, 'c3');
      expect(notification.campaign?.audience, isNull);
    });
  });

  group('localized content', () {
    test('the preferred language wins and falls back to the other one', () {
      final notification = _notification(
        titleAr: 'عرض خاص',
        titleEn: 'Special offer',
        bodyAr: 'جسم عربي',
        bodyEn: 'English body',
      );

      expect(notification.titleFor(AppLanguage.arabic), 'عرض خاص');
      expect(notification.titleFor(AppLanguage.english), 'Special offer');
      expect(notification.bodyFor(AppLanguage.english), 'English body');

      final arabicOnly = _notification(titleAr: 'عربي فقط', bodyEn: 'English');
      expect(arabicOnly.titleFor(AppLanguage.english), 'عربي فقط');
      expect(arabicOnly.bodyFor(AppLanguage.arabic), 'English');
    });

    test('the headline falls back to the body and then to a label', () {
      expect(
        notificationTitle(
          _notification(titleEn: 'Special offer', bodyEn: 'Today only'),
        ),
        'Special offer',
      );
      expect(
        notificationTitle(_notification(bodyEn: 'Today only')),
        'Today only',
      );
      expect(notificationTitle(_notification()), S.notificationsUntitled);
    });

    test('the excerpt is hidden when it repeats the title', () {
      expect(
        notificationExcerpt(
          _notification(titleEn: 'Special offer', bodyEn: 'Today only'),
        ),
        'Today only',
      );
      expect(notificationExcerpt(_notification(bodyEn: 'Today only')), isNull);
      expect(
        notificationExcerpt(_notification(titleEn: 'Same', bodyEn: 'Same')),
        isNull,
      );
    });
  });

  group('customer helpers', () {
    test('the name falls back from name to email to phone to anonymous', () {
      final named = _notification();
      final emailOnly = _notification(
        customer: const AdminNotificationCustomer(
          id: 'u2',
          email: 'guest@example.com',
        ),
      );
      final phoneOnly = _notification(
        customer: const AdminNotificationCustomer(
          id: 'u3',
          phone: '+201111111111',
        ),
      );
      final anonymous = _notification(
        customer: const AdminNotificationCustomer(id: 'u4'),
      );

      expect(notificationCustomerName(named), 'Mona');
      expect(notificationCustomerDetail(named), 'mona@example.com');
      expect(notificationCustomerName(emailOnly), 'guest@example.com');
      expect(notificationCustomerName(phoneOnly), '+201111111111');
      expect(notificationCustomerName(anonymous), S.reviewsAnonymous);
      expect(notificationCustomerInitial(named), 'M');
      expect(
        notificationCustomerInitial(anonymous),
        S.reviewsAnonymous.substring(0, 1).toUpperCase(),
      );
    });
  });

  group('labels', () {
    test('the type, audience and source are localized', () {
      expect(
        notificationTypeLabel(AdminNotificationType.orderStatus),
        S.notificationsTypeOrder,
      );
      expect(
        notificationTypeLabel(AdminNotificationType.subscription),
        S.notificationsTypeSubscription,
      );
      expect(
        notificationAudienceLabel(AdminNotificationAudience.all),
        S.notificationsAudienceAll,
      );
      expect(
        notificationAudienceLabel(AdminNotificationAudience.customer),
        S.notificationsAudienceCustomer,
      );
      expect(notificationAudienceLabel(null), S.notificationsSourceCampaign);
      expect(
        notificationSourceLabel(_notification()),
        S.notificationsSourceAutomatic,
      );
      expect(
        notificationSourceLabel(
          _notification(
            campaign: const AdminNotificationCampaign(
              id: 'c1',
              audience: AdminNotificationAudience.all,
            ),
          ),
        ),
        S.notificationsSourceCampaign,
      );
    });

    test('the source detail prefers the campaign audience', () {
      expect(
        notificationSourceDetail(
          _notification(
            campaign: const AdminNotificationCampaign(
              id: 'c1',
              audience: AdminNotificationAudience.hasDevice,
            ),
          ),
        ),
        S.notificationsAudienceHasDevice,
      );
      expect(
        notificationSourceDetail(_notification(relatedType: 'order')),
        S.notificationsRelatedOrder,
      );
      expect(notificationSourceDetail(_notification()), isNull);
    });

    test('the push badge maps every delivery state', () {
      expect(
        notificationPushLabel(AdminNotificationPushState.sent),
        S.notificationsPushSent,
      );
      expect(
        notificationPushLabel(AdminNotificationPushState.failed),
        S.notificationsPushFailed,
      );
      expect(
        notificationPushLabel(AdminNotificationPushState.skipped),
        S.notificationsPushSkipped,
      );
      expect(
        notificationPushLabel(AdminNotificationPushState.none),
        S.notificationsPushNone,
      );
    });
  });

  group('metrics', () {
    test('the counters, the type breakdown and push health are parsed', () {
      final metrics = AdminNotificationMetrics.fromJson(<String, dynamic>{
        'total': 120,
        'unread': 8,
        'today': 5,
        'this_month': 32,
        'admin_sent': 40,
        'admin_sent_month': 12,
        'campaigns': 6,
        'customers_total': 900,
        'push_enabled_customers': 300,
        'reachable_customers': 260,
        'devices_total': 340,
        'push_success_rate': 93.4,
        'push': {'sent': 180, 'failed': 9, 'skipped': 4, 'invalid_token': 3},
        'by_type': {
          'order_status': 70,
          'promo': 20,
          'system': 10,
          'loyalty': 15,
          'subscription': 5,
        },
      });

      expect(metrics.total, 120);
      expect(metrics.unread, 8);
      expect(metrics.today, 5);
      expect(metrics.thisMonth, 32);
      expect(metrics.adminSent, 40);
      expect(metrics.adminSentMonth, 12);
      expect(metrics.campaigns, 6);
      expect(metrics.customersTotal, 900);
      expect(metrics.pushEnabledCustomers, 300);
      expect(metrics.reachableCustomers, 260);
      expect(metrics.devicesTotal, 340);
      expect(metrics.pushSuccessRate, 93.4);
      expect(metrics.pushSent, 180);
      expect(metrics.pushFailed, 9);
      expect(metrics.pushSkipped, 4);
      expect(metrics.pushInvalidToken, 3);
      expect(metrics.countFor(AdminNotificationType.orderStatus), 70);
      expect(metrics.countFor(AdminNotificationType.loyalty), 15);
      expect(metrics.countFor(AdminNotificationType.system), 10);
    });

    test('missing counters read as zero and the rate stays null', () {
      final metrics = AdminNotificationMetrics.fromJson(<String, dynamic>{
        'total': 0,
      });

      expect(metrics.total, 0);
      expect(metrics.pushSuccessRate, isNull);
      expect(metrics.pushSent, 0);
      expect(metrics.countFor(AdminNotificationType.promo), 0);
      expect(metrics.byType.keys, AdminNotificationType.values);
      expect(AdminNotificationMetrics.empty.total, 0);
    });

    test('the formatted counters follow the dashboard style', () {
      expect(notificationCountValue(1200), '1,200');
      expect(notificationPercentValue(42.6), '43%');
      expect(notificationRateValue(92.4), '92.4%');
      expect(notificationRateValue(null), '—');
      expect(
        notificationRowsLabel(1, 10, 25),
        'Showing 1–10 of 25 notifications',
      );
    });
  });

  group('push health', () {
    test('a fully configured chain is ready', () {
      final health = AdminPushHealth.fromJson(<String, dynamic>{
        'vault_available': true,
        'webhook_secret_configured': true,
        'pg_net_installed': true,
        'dispatch_trigger_installed': true,
        'function_url': 'https://example.supabase.co/functions/v1/send-push',
        'function_url_configured': true,
        'devices_total': 12,
        'devices_android': 7,
        'devices_ios': 5,
        'devices_with_locale': 10,
        'customers_total': 40,
        'push_enabled_customers': 20,
        'reachable_customers': 18,
        'deliveries_30d': {
          'sent': 90,
          'failed': 4,
          'skipped': 2,
          'invalid_token': 1,
        },
        'last_success_at': '2026-10-05T10:00:00Z',
        'last_webhook_status': 200,
        'last_webhook_at': '2026-10-05T09:59:00Z',
      });

      expect(health.databaseReady, isTrue);
      expect(health.hasReachableDevices, isTrue);
      expect(health.devicesAndroid, 7);
      expect(health.devicesIos, 5);
      expect(health.reachableCustomers, 18);
      expect(health.delivered30d, 90);
      expect(health.failed30d, 4);
      expect(health.skipped30d, 2);
      expect(health.invalidToken30d, 1);
      expect(health.lastWebhookStatus, 200);
      expect(health.lastSuccessAt?.toUtc(), DateTime.utc(2026, 10, 5, 10));
      expect(
        notificationPushHealthStatus(health),
        NotificationPushHealthStatus.ready,
      );
      expect(
        notificationPushHealthLabel(NotificationPushHealthStatus.ready),
        S.notificationsPushHealthy,
      );
      expect(
        notificationHealthChecks(health).every((check) => check.ok),
        isTrue,
      );
    });

    test('a missing database piece is incomplete', () {
      const health = AdminPushHealth(
        vaultAvailable: true,
        webhookSecretConfigured: false,
        pgNetInstalled: true,
        dispatchTriggerInstalled: true,
        functionUrlConfigured: true,
        reachableCustomers: 5,
      );

      expect(health.databaseReady, isFalse);
      expect(
        notificationPushHealthStatus(health),
        NotificationPushHealthStatus.incomplete,
      );
      final checks = notificationHealthChecks(health);
      expect(checks, hasLength(5));
      expect(checks.where((check) => !check.ok), hasLength(1));
      expect(
        notificationPushHealthLabel(NotificationPushHealthStatus.incomplete),
        S.notificationsPushError,
      );
    });

    test('a reachable but unhealthy chain warns', () {
      const noDevices = AdminPushHealth(
        vaultAvailable: true,
        webhookSecretConfigured: true,
        pgNetInstalled: true,
        dispatchTriggerInstalled: true,
        functionUrlConfigured: true,
        reachableCustomers: 0,
      );
      const webhookFailure = AdminPushHealth(
        vaultAvailable: true,
        webhookSecretConfigured: true,
        pgNetInstalled: true,
        dispatchTriggerInstalled: true,
        functionUrlConfigured: true,
        reachableCustomers: 3,
        lastWebhookStatus: 500,
      );
      const deliveryFailure = AdminPushHealth(
        vaultAvailable: true,
        webhookSecretConfigured: true,
        pgNetInstalled: true,
        dispatchTriggerInstalled: true,
        functionUrlConfigured: true,
        reachableCustomers: 3,
        lastError: 'FCM rejected the token',
      );

      expect(noDevices.hasReachableDevices, isFalse);
      expect(
        notificationPushHealthStatus(noDevices),
        NotificationPushHealthStatus.warning,
      );
      expect(
        notificationPushHealthStatus(webhookFailure),
        NotificationPushHealthStatus.warning,
      );
      expect(
        notificationPushHealthStatus(deliveryFailure),
        NotificationPushHealthStatus.warning,
      );
    });
  });
}
