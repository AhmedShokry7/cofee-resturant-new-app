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
  /// [limit] rows, newest first, starting after [offset] of them.
  Future<List<NotificationModel>> listNotifications({
    int limit = 50,
    int offset = 0,
  });
  Future<int> markRead(List<String> ids);

  Future<int> deleteNotifications(List<String> ids) async => 0;
  Future<int> deleteAllNotifications() async => 0;
}

/// Optional single-RPC capability for marking every unread row for the
/// current customer.
abstract interface class BulkNotificationsReadRepository {
  Future<int> markAllRead();
}

class NotificationsRepositoryImpl
    implements NotificationsRepository, BulkNotificationsReadRepository {
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
  Future<List<NotificationModel>> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Notifications need a configured Supabase backend.');
    }
    _requireUserId(client);

    final pageSize = limit.clamp(1, 200);
    final first = offset.clamp(0, 100000);
    final rows =
        await client
                .from('notifications')
                .select(
                  'id, type, title_ar, title_en, body_ar, body_en, related_entity_type, related_entity_id, payload, is_read, created_at',
                )
                .order('created_at', ascending: false)
                .range(first, first + pageSize - 1)
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

  @override
  Future<int> markAllRead() async {
    final client = _client;
    if (client == null) {
      throw StateError('Notifications need a configured Supabase backend.');
    }
    _requireUserId(client);
    final result = await client.rpc('mark_notifications_read');
    if (result is num) return result.toInt();
    if (result is List && result.isNotEmpty && result.first is num) {
      return (result.first as num).toInt();
    }
    return 0;
  }

  @override
  Future<int> deleteNotifications(List<String> ids) async {
    final client = _client;
    if (client == null) {
      throw StateError('Notifications need a configured Supabase backend.');
    }
    if (ids.isEmpty) return 0;
    _requireUserId(client);
    final result = await client.rpc(
      'delete_notifications',
      params: {'p_ids': ids},
    );
    return _rpcCount(result);
  }

  @override
  Future<int> deleteAllNotifications() async {
    final client = _client;
    if (client == null) {
      throw StateError('Notifications need a configured Supabase backend.');
    }
    _requireUserId(client);
    final result = await client.rpc(
      'delete_notifications',
      params: {'p_ids': null},
    );
    return _rpcCount(result);
  }

  int _rpcCount(dynamic result) {
    if (result is num) return result.toInt();
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is num) return first.toInt();
      if (first is Map && first.values.isNotEmpty) {
        final value = first.values.first;
        if (value is num) return value.toInt();
      }
    }
    if (result is Map && result.values.isNotEmpty) {
      final value = result.values.first;
      if (value is num) return value.toInt();
    }
    return 0;
  }
}
