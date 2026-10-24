import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';

class AdminCustomerRepository {
  AdminCustomerRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<AdminCustomer>> loadCustomers() async {
    final response = await _supabase.rpc('admin_customers');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminCustomer.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    return const <AdminCustomer>[];
  }

  Future<Map<String, dynamic>> loadCustomerDetails(String customerId) async {
    final response = await _supabase.rpc(
      'admin_customer_details',
      params: {'p_customer_id': customerId},
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is String && response.isNotEmpty) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  Future<void> updateCustomer(
    String customerId, {
    bool? isVip,
    bool? isBlacklisted,
    String? adminNotes,
  }) async {
    await _supabase.rpc(
      'admin_update_customer',
      params: {
        'p_customer_id': customerId,
        'p_is_vip': isVip,
        'p_is_blacklisted': isBlacklisted,
        'p_admin_notes': adminNotes,
      },
    );
  }
}
