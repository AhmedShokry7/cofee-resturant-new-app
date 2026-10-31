import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/notification_json.dart';

/// One page of the server-filtered notification directory.
class AdminNotificationPage {
  const AdminNotificationPage({this.total = 0, this.rows = const []});

  final int total;
  final List<AdminNotification> rows;

  factory AdminNotificationPage.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    return AdminNotificationPage(
      total: notificationInt(json['total']),
      rows: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => AdminNotification.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList(growable: false)
          : const <AdminNotification>[],
    );
  }
}

/// A customer the composer can address, with their push readiness.
class AdminNotificationComposerCustomer {
  const AdminNotificationComposerCustomer({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.pushEnabled = false,
    this.deviceCount = 0,
    this.hasPush = false,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool pushEnabled;
  final int deviceCount;
  final bool hasPush;

  factory AdminNotificationComposerCustomer.fromJson(
    Map<String, dynamic> json,
  ) => AdminNotificationComposerCustomer(
    id: '${json['id'] ?? ''}',
    fullName: notificationText(json['full_name']),
    email: notificationText(json['email']),
    phone: notificationText(json['phone']),
    avatarUrl: notificationText(json['avatar_url']),
    pushEnabled: json['push_enabled'] == true,
    deviceCount: notificationInt(json['device_count']),
    hasPush: json['has_push'] == true,
  );
}

/// A composed message that is ready to be sent.
///
/// The payload the database hands to the push function is built here and only
/// here: the composer offers a picture and a destination, and anything the
/// customer app cannot read is never written into the row.
class AdminNotificationDraft {
  const AdminNotificationDraft({
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.audience,
    this.customerId,
    this.imageUrl,
    this.destination = AdminNotificationDestination.none,
  });

  final AdminNotificationType type;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final AdminNotificationAudience audience;
  final String? customerId;

  /// The public address of the campaign picture, or null.
  final String? imageUrl;

  /// The screen the notification opens, or none.
  final AdminNotificationDestination destination;

  Map<String, dynamic> get payload => <String, dynamic>{
    if (_image != null) 'image_url': _image,
    if (destination.value != null) 'destination': destination.value,
  };

  String? get _image {
    final image = imageUrl?.trim();
    return image == null || image.isEmpty ? null : image;
  }
}

/// How many customers a draft would reach, and how many are push-ready.
class AdminAudienceEstimate {
  const AdminAudienceEstimate({this.count = 0, this.pushReady = 0});

  final int count;
  final int pushReady;

  static const empty = AdminAudienceEstimate();

  factory AdminAudienceEstimate.fromJson(Map<String, dynamic> json) =>
      AdminAudienceEstimate(
        count: notificationInt(json['count']),
        pushReady: notificationInt(json['push_ready']),
      );
}

/// The outcome of composing and sending a campaign.
class AdminSendResult {
  const AdminSendResult({
    required this.ok,
    this.reason,
    this.campaignId,
    this.recipients = 0,
    this.pushReady = 0,
  });

  final bool ok;
  final String? reason;
  final String? campaignId;
  final int recipients;
  final int pushReady;

  factory AdminSendResult.fromJson(Map<String, dynamic> json) =>
      AdminSendResult(
        ok: json['ok'] == true,
        reason: notificationText(json['reason']),
        campaignId: notificationText(json['campaign_id']),
        recipients: notificationInt(json['recipients']),
        pushReady: notificationInt(json['push_ready']),
      );
}

/// The outcome of asking the database to queue a push again.
class AdminResendResult {
  const AdminResendResult({required this.ok, this.queued = false, this.reason});

  final bool ok;
  final bool queued;
  final String? reason;

  factory AdminResendResult.fromJson(Map<String, dynamic> json) =>
      AdminResendResult(
        ok: json['ok'] == true,
        queued: json['queued'] == true,
        reason: notificationText(json['reason']),
      );
}
