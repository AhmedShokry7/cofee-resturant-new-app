import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
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
    int pageSize = 10,
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

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _isOk(Object? response) =>
      response is Map && response['ok'] == true;

  static String _reason(Object? response) =>
      response is Map ? '${response['reason'] ?? ''}' : '';
}
