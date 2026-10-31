import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';

class AdminSubscriptionRepository implements SubscriptionRepository {
  AdminSubscriptionRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminSubscription>> loadSubscriptions() async {
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc('admin_subscriptions'),
      client: _supabase,
    );
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

  @override
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

  @override
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
