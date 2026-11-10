import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/notifications/domain/entities/notification_json.dart';

/// The notification kinds the database can produce.
enum AdminNotificationType {
  orderStatus('order_status'),
  promo('promo'),
  system('system'),
  loyalty('loyalty'),
  subscription('subscription');

  const AdminNotificationType(this.value);

  /// The value stored in `engagement.notifications.type`.
  final String value;

  static AdminNotificationType fromValue(Object? value) {
    for (final type in AdminNotificationType.values) {
      if (type.value == value) return type;
    }
    return AdminNotificationType.system;
  }
}

/// The kinds of message an admin can compose.
const List<AdminNotificationType> kComposableNotificationTypes =
    <AdminNotificationType>[
      AdminNotificationType.promo,
      AdminNotificationType.system,
      AdminNotificationType.loyalty,
    ];

/// The screen a campaign sends its reader to.
///
/// The customer app matches this code against the routes it already registers,
/// so a campaign can only open a screen the app knows: the composer never
/// offers a path, and a code outside this list opens nothing.
enum AdminNotificationDestination {
  none(null),
  offers('offers'),
  orders('orders'),
  loyalty('loyalty'),
  subscription('subscription'),
  notifications('notifications');

  const AdminNotificationDestination(this.value);

  /// The value stored in `engagement.notifications.payload ->> 'destination'`.
  final String? value;

  static AdminNotificationDestination fromValue(Object? value) {
    for (final destination in AdminNotificationDestination.values) {
      final stored = destination.value;
      if (stored != null && stored == value) return destination;
    }
    return AdminNotificationDestination.none;
  }
}

/// The audience a campaign was sent to.
enum AdminNotificationAudience {
  all('all'),
  pushEnabled('push_enabled'),
  hasDevice('has_device'),
  customer('customer');

  const AdminNotificationAudience(this.value);

  final String value;

  static AdminNotificationAudience? fromValue(Object? value) {
    for (final audience in AdminNotificationAudience.values) {
      if (audience.value == value) return audience;
    }
    return null;
  }
}

/// The result of the latest push attempt of one notification.
enum AdminNotificationPushState {
  none('none'),
  sent('sent'),
  failed('failed'),
  skipped('skipped');

  const AdminNotificationPushState(this.value);

  final String value;

  static AdminNotificationPushState fromValue(Object? value) {
    for (final state in AdminNotificationPushState.values) {
      if (state.value == value) return state;
    }
    return AdminNotificationPushState.none;
  }
}

class AdminNotificationCustomer {
  const AdminNotificationCustomer({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  factory AdminNotificationCustomer.fromJson(Map<String, dynamic> json) =>
      AdminNotificationCustomer(
        id: '${json['id'] ?? ''}',
        fullName: notificationText(json['full_name']),
        email: notificationText(json['email']),
        phone: notificationText(json['phone']),
        avatarUrl: notificationText(json['avatar_url']),
      );
}

class AdminNotificationCampaign {
  const AdminNotificationCampaign({
    required this.id,
    this.audience,
    this.recipientCount = 0,
    this.createdAt,
    this.isSummary = false,
    this.readCount = 0,
    this.unreadCount = 0,
    this.emailSent = 0,
    this.emailFailed = 0,
    this.emailSkipped = 0,
  });

  final String id;
  final AdminNotificationAudience? audience;
  final int recipientCount;
  final DateTime? createdAt;
  final bool isSummary;
  final int readCount;
  final int unreadCount;
  final int emailSent;
  final int emailFailed;
  final int emailSkipped;

  factory AdminNotificationCampaign.fromJson(Map<String, dynamic> json) =>
      AdminNotificationCampaign(
        id: '${json['id'] ?? ''}',
        audience: AdminNotificationAudience.fromValue(json['audience']),
        recipientCount: notificationInt(json['recipient_count']),
        createdAt: notificationDate(json['created_at']),
        isSummary: json['is_summary'] == true,
        readCount: notificationInt(json['read_count']),
        unreadCount: notificationInt(json['unread_count']),
        emailSent: notificationInt(json['email_sent']),
        emailFailed: notificationInt(json['email_failed']),
        emailSkipped: notificationInt(json['email_skipped']),
      );
}

/// What happened when the database handed this notification to the push
/// service, aggregated over every delivery attempt.
class AdminNotificationPush {
  const AdminNotificationPush({
    required this.state,
    this.total = 0,
    this.sent = 0,
    this.failed = 0,
    this.invalidToken = 0,
    this.skipped = 0,
    this.lastAt,
    this.lastError,
  });

  final AdminNotificationPushState state;
  final int total;
  final int sent;
  final int failed;
  final int invalidToken;
  final int skipped;
  final DateTime? lastAt;
  final String? lastError;

  bool get hasAttempts => total > 0;

  factory AdminNotificationPush.fromJson(Map<String, dynamic> json) =>
      AdminNotificationPush(
        state: AdminNotificationPushState.fromValue(json['state']),
        total: notificationInt(json['total']),
        sent: notificationInt(json['sent']),
        failed: notificationInt(json['failed']),
        invalidToken: notificationInt(json['invalid_token']),
        skipped: notificationInt(json['skipped']),
        lastAt: notificationDate(json['last_at']),
        lastError: notificationText(json['last_error']),
      );
}

class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.type,
    required this.customer,
    required this.push,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
    this.payload = const <String, dynamic>{},
    this.relatedEntityType,
    this.relatedEntityId,
    this.isRead = false,
    this.readAt,
    this.createdAt,
    this.campaign,
  });

  final String id;
  final AdminNotificationType type;
  final AdminNotificationCustomer customer;
  final AdminNotificationPush push;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final Map<String, dynamic> payload;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;
  final AdminNotificationCampaign? campaign;

  bool get isAdminSent => campaign != null;
  bool get isCampaignSummary => campaign?.isSummary == true;

  /// The picture the campaign carries, or null for a plain message.
  String? get imageUrl => notificationText(payload['image_url']);

  /// The screen the campaign points at; [AdminNotificationDestination.none]
  /// when it carries no code the app recognises.
  AdminNotificationDestination get destination =>
      AdminNotificationDestination.fromValue(payload['destination']);

  String? titleFor(AppLanguage language) =>
      _localized(titleAr, titleEn, language);

  String? bodyFor(AppLanguage language) => _localized(bodyAr, bodyEn, language);

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    final customer = notificationMap(json['customer']);
    final campaign = notificationMap(json['campaign']);
    final push = notificationMap(json['push']);
    return AdminNotification(
      id: '${json['id'] ?? ''}',
      type: AdminNotificationType.fromValue(json['type']),
      customer: customer == null
          ? const AdminNotificationCustomer(id: '')
          : AdminNotificationCustomer.fromJson(customer),
      push: push == null
          ? const AdminNotificationPush(state: AdminNotificationPushState.none)
          : AdminNotificationPush.fromJson(push),
      titleAr: notificationText(json['title_ar']),
      titleEn: notificationText(json['title_en']),
      bodyAr: notificationText(json['body_ar']),
      bodyEn: notificationText(json['body_en']),
      payload: notificationPayload(json['payload']),
      relatedEntityType: notificationText(json['related_entity_type']),
      relatedEntityId: notificationText(json['related_entity_id']),
      isRead: json['is_read'] == true,
      readAt: notificationDate(json['read_at']),
      createdAt: notificationDate(json['created_at']),
      campaign: campaign == null
          ? null
          : AdminNotificationCampaign.fromJson(campaign),
    );
  }
}

String? _localized(String? arabic, String? english, AppLanguage language) {
  final preferred = language.isArabic ? arabic : english;
  if (preferred != null && preferred.isNotEmpty) return preferred;
  final fallback = language.isArabic ? english : arabic;
  return fallback != null && fallback.isNotEmpty ? fallback : null;
}
