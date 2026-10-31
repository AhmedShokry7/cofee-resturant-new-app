import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSignInRequiredException implements Exception {
  const NotificationSignInRequiredException();

  @override
  String toString() => 'Sign in to view notifications.';
}

/// Customer-owned in-app notifications.
///
/// Rows are created by server triggers, never by the client. Reads use the
/// owner-scoped bridge view; marking read uses the ownership-checked RPC.
abstract class NotificationsRepository {
  Future<List<NotificationModel>> listNotifications({int limit = 50});
  Future<int> markRead(List<String> ids);
}

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  String _requireUserId(SupabaseClient client) {
    final user = client.auth.currentUser;
    if (user == null) throw const NotificationSignInRequiredException();
    return user.id;
  }

  @override
  Future<List<NotificationModel>> listNotifications({int limit = 50}) async {
    final client = _client;
    if (client == null) {
      throw StateError('Notifications need a configured Supabase backend.');
    }
    _requireUserId(client);

    final rows =
        await client
                .from('notifications')
                .select(
                  'id, type, title_ar, title_en, body_ar, body_en, related_entity_type, related_entity_id, payload, is_read, created_at',
                )
                .order('created_at', ascending: false)
                .limit(limit.clamp(1, 200))
            as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) NotificationModel.fromDatabase(row),
    ];
  }

  @override
  Future<int> markRead(List<String> ids) async {
    final client = _client;
    if (client == null) {
      throw StateError('Notifications need a configured Supabase backend.');
    }
    if (ids.isEmpty) return 0;
    _requireUserId(client);
    final rows = await client.rpc(
      'mark_notifications_read',
      params: {'p_ids': ids},
    ) as List;
    if (rows.isEmpty) return 0;
    return (rows.first as num?)?.toInt() ?? 0;
  }
}
