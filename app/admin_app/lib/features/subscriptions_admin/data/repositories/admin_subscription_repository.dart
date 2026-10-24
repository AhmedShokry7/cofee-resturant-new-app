import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';

class AdminSubscriptionRepository {
  AdminSubscriptionRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<AdminSubscription>> loadSubscriptions() async {
    final response = await _supabase.rpc('admin_subscriptions');
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) => AdminSubscription.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminSubscription>[];
  }
}
