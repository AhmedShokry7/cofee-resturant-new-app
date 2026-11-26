import 'package:new_coffee/core/services/supabase_service.dart';

class OrderIssueRepository {
  const OrderIssueRepository();
  Future<List<Map<String, dynamic>>> list(String order) async =>
      List<Map<String, dynamic>>.from(
        await SupabaseService.client.rpc(
          'customer_order_issues',
          params: {'p_order': order},
        ) as List,
      );
  Future<void> report(
    String order,
    String? item,
    String reason,
    String message,
    String? photo,
  ) async {
    await SupabaseService.client.rpc(
      'report_order_issue',
      params: {
        'p_order': order,
        'p_item': item,
        'p_reason': reason,
        'p_message': message,
        'p_photo': photo,
      },
    );
  }
}
