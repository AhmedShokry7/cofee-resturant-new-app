import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription_usage.dart';

enum SubscriptionCancelOutcome {
  cancelled,
  notFound,
  notCancellable,
  reservedCups,
  failed,
}

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

  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId) async {
    final response = await _supabase.rpc(
      'admin_subscription_usage',
      params: {'p_subscription_id': subscriptionId},
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) =>
                AdminSubscriptionUsage.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminSubscriptionUsage>[];
  }

  Future<SubscriptionCancelOutcome> cancelSubscription(
    String subscriptionId,
  ) async {
    final response = await _supabase.rpc(
      'admin_cancel_subscription',
      params: {'p_subscription_id': subscriptionId},
    );
    if (response is! Map) return SubscriptionCancelOutcome.failed;
    if (response['ok'] == true) return SubscriptionCancelOutcome.cancelled;
    return switch ('${response['reason'] ?? ''}') {
      'not_found' => SubscriptionCancelOutcome.notFound,
      'not_cancellable' => SubscriptionCancelOutcome.notCancellable,
      'reserved_cups' => SubscriptionCancelOutcome.reservedCups,
      _ => SubscriptionCancelOutcome.failed,
    };
  }
}
