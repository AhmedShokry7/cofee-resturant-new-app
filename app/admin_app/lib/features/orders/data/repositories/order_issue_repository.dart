import 'package:admin_app/core/services/supabase_service.dart';

class OrderIssueRepository {
  const OrderIssueRepository();
  Future<List<Map<String, dynamic>>> list(String order) async =>
      List<Map<String, dynamic>>.from(
        await SupabaseService.client.rpc(
          'customer_order_issues',
          params: {'p_order': order},
        ) as List,
      );
  Future<void> reply(String issue, String reply) async {
    await SupabaseService.client.rpc(
      'reply_order_issue',
      params: {'p_issue': issue, 'p_reply': reply},
    );
  }
}
