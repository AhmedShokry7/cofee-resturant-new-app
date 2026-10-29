import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/customers/customer_details_reader.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/admin_avatar_links.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer_metrics.dart';
import 'package:admin_app/features/customers/domain/repositories/customer_repository.dart';

class AdminCustomerRepository
    implements CustomerDetailsReader, CustomerRepository {
  AdminCustomerRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminCustomer>> loadCustomers() async {
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc('admin_customers'),
      client: _supabase,
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminCustomer.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    return const <AdminCustomer>[];
  }

  @override
  Future<AdminCustomerMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_customer_metrics');
    if (response is Map) {
      return AdminCustomerMetrics.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminCustomerMetrics.empty;
  }

  @override
  Future<Map<String, dynamic>> loadCustomerDetails(String customerId) async {
    final response = await AdminAvatarLinks.signTree(
      await _supabase.rpc(
        'admin_customer_details',
        params: {'p_customer_id': customerId},
      ),
      client: _supabase,
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    // الدالة ترجع NULL على معرّف لا صفّ عميل له، فصف هنا كان يعرض بطاقة فارغة
    // كأنها حالة فراغ حقيقية. الرفض يستدعي مسار الفشل عند المنادِيَيْن: حوار
    // السجل وورقة الطلب.
    throw Exception(S.customerHistoryLoadFailed);
  }

  @override
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
