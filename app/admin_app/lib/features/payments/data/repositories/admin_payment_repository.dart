import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/domain/repositories/payment_repository.dart';

class AdminPaymentRepository implements PaymentRepository {
  AdminPaymentRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminPayment>> loadPayments() async {
    final response = await _supabase.rpc('admin_payments');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminPayment.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    return const <AdminPayment>[];
  }
}
