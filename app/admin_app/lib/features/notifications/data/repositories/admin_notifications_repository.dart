import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/notifications/data/campaign_push_image.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

enum NotificationSendOutcome { success, noRecipients, customerNotFound, failed }

enum NotificationResendOutcome { queued, pushNotConfigured, notFound, failed }

class AdminNotificationsRepository implements NotificationsRepository {
  AdminNotificationsRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<AdminNotificationPage> loadNotifications({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    int page = 0,
    int pageSize = AdminNotificationsPaging.pageSize,
  }) async {
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc(
        'admin_notifications',
        params: {
          'p_search': _blankToNull(search),
          'p_type': type?.value,
          'p_read': isRead,
          'p_push': pushState,
          'p_limit': pageSize,
          'p_offset': page * pageSize,
        },
      ),
      client: _supabase,
    );
    if (response is Map) {
      return AdminNotificationPage.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return const AdminNotificationPage();
  }

  @override
  Future<AdminNotificationMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_notification_metrics');
    if (response is Map) {
      return AdminNotificationMetrics.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminNotificationMetrics.empty;
  }

  @override
  Future<AdminPushHealth> loadPushHealth() async {
    final response = await _supabase.rpc('admin_push_health');
    if (response is Map) {
      return AdminPushHealth.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminPushHealth();
  }

  @override
  Future<List<AdminNotificationComposerCustomer>> loadCustomers({
    String? search,
    int limit = 20,
  }) async {
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc(
        'admin_notification_customers',
        params: {'p_search': _blankToNull(search), 'p_limit': limit},
      ),
      client: _supabase,
    );
    if (response is! List) return const <AdminNotificationComposerCustomer>[];
    return response
        .whereType<Map>()
        .map(
          (row) => AdminNotificationComposerCustomer.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AdminAudienceEstimate> loadAudience({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  }) async {
    final response = await _supabase.rpc(
      'admin_notification_audience',
      params: {
        'p_type': type.value,
        'p_audience': audience.value,
        'p_user_id': customerId,
      },
    );
    if (response is Map) {
      return AdminAudienceEstimate.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminAudienceEstimate.empty;
  }

  @override
  Future<AdminSendResult> sendNotification({
    required AdminNotificationType type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required AdminNotificationAudience audience,
    String? customerId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final response = await _supabase.rpc(
      'admin_send_notification',
      params: {
        'p_type': type.value,
        'p_title_ar': titleAr,
        'p_title_en': titleEn,
        'p_body_ar': bodyAr,
        'p_body_en': bodyEn,
        'p_audience': audience.value,
        'p_user_id': customerId,
        'p_payload': payload,
      },
    );
    if (response is Map) {
      return AdminSendResult.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminSendResult(ok: false);
  }

  @override
  Future<AdminResendResult> resendNotification(String notificationId) async {
    final response = await _supabase.rpc(
      'admin_resend_notification',
      params: {'p_notification_id': notificationId},
    );
    if (response is Map) {
      return AdminResendResult.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminResendResult(ok: false);
  }

  @override
  Future<NotificationMutationOutcome> setRead(
    String notificationId,
    bool read,
  ) async {
    final response = await _supabase.rpc(
      'admin_set_notification_read',
      params: {'p_notification_id': notificationId, 'p_read': read},
    );
    if (_isOk(response)) return NotificationMutationOutcome.success;
    return _reason(response) == 'not_found'
        ? NotificationMutationOutcome.notFound
        : NotificationMutationOutcome.failed;
  }

  @override
  Future<NotificationMutationOutcome> deleteNotification(
    String notificationId,
  ) async {
    final response = await _supabase.rpc(
      'admin_delete_notification',
      params: {'p_notification_id': notificationId},
    );
    if (_isOk(response)) return NotificationMutationOutcome.success;
    return _reason(response) == 'not_found'
        ? NotificationMutationOutcome.notFound
        : NotificationMutationOutcome.failed;
  }

  @override
  Future<String> uploadCampaignImage({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    // سقف الصورة هنا سقف FCM لا سقف الدلو: صورة أنجح من الحد تُرفع وتُقبل
    // وتصل بلا بانر مصوَّر، فلا فائدة من حفظها أصلية.
    final image = await campaignPushImageOf(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    final path =
        'products/notifications/${DateTime.now().microsecondsSinceEpoch}'
        '${_extensionOf(image.fileName)}';

    await _supabase.storage
        .from(_imageBucket)
        .uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(contentType: image.type, upsert: false),
        );

    return '$_publicPrefix$path';
  }

  @override
  Future<void> deleteCampaignImageFile(String? imageUrl) async {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty || !url.startsWith(_publicPrefix)) return;
    try {
      await _supabase.storage.from(_imageBucket).remove([
        url.substring(_publicPrefix.length),
      ]);
    } catch (_) {
      // A picture left behind in the bucket blocks nothing; the row that
      // pointed at it is already gone.
    }
  }

  /// The bucket the push function accepts, and the only prefix a campaign
  /// picture can be removed by: anything else is not this app's object.
  static const String _imageBucket = 'product-images';
  static String get _publicPrefix =>
      '${AppConfig.supabaseUrl}/storage/v1/object/public/$_imageBucket/';

  static String _extensionOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';
}
