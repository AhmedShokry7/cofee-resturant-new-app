import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';
import 'package:admin_app/features/shell/domain/repositories/nav_repository.dart';

/// The numbers the sidebar shows without opening a page.
class AdminNavRepository implements NavRepository {
  AdminNavRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<AdminNavCounts> loadCounts({bool withNotifications = false}) async {
    if (_client == null && !SupabaseService.isReady) {
      return AdminNavCounts.empty;
    }
    final response = await _supabase.rpc('admin_nav_counts');
    final counts = response is Map
        ? AdminNavCounts.fromJson(Map<String, dynamic>.from(response))
        : AdminNavCounts.empty;
    if (!withNotifications) return counts;
    return counts.copyWithUnreadNotifications(await _unreadNotifications());
  }

  /// Customer notifications no one has opened.
  ///
  /// Read from the same RPC the notifications page reads, asked for the total
  /// behind one row, so the badge and the page cannot count differently and no
  /// migration is needed for a number the sidebar already has a place for.
  ///
  /// A refusal is read as zero: `admin_notifications` raises 42501 for an
  /// account without `notifications.read`, and dropping the counters the
  /// account is allowed to see would punish orders and kitchen for one answer.
  Future<int> _unreadNotifications() async {
    try {
      final response = await _supabase.rpc(
        'admin_notifications',
        params: const <String, Object?>{
          'p_read': false,
          'p_limit': 1,
          'p_offset': 0,
        },
      );
      if (response is! Map) return 0;
      final total = response['total'];
      if (total is num) return total.toInt();
      return int.tryParse('${total ?? ''}') ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
