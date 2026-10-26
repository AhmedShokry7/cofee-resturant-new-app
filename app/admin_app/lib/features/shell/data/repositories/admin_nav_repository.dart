import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/shell/data/models/admin_nav_counts.dart';

/// The two numbers the sidebar shows without opening a page.
class AdminNavRepository {
  AdminNavRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<AdminNavCounts> loadCounts() async {
    if (_client == null && !SupabaseService.isReady) {
      return AdminNavCounts.empty;
    }
    final response = await _supabase.rpc('admin_nav_counts');
    if (response is Map) {
      return AdminNavCounts.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminNavCounts.empty;
  }
}
