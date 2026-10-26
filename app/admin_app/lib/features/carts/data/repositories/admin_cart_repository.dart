import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/domain/repositories/cart_repository.dart';

class AdminCartRepository implements CartRepository {
  AdminCartRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<AdminCart>> loadCarts() async {
    final response = await _supabase.rpc('admin_abandoned_carts');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminCart.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    if (response is String && response.isNotEmpty) {
      return const <AdminCart>[];
    }
    return const <AdminCart>[];
  }
}
