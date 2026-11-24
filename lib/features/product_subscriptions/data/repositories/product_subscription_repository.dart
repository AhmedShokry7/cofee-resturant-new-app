import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';

class ProductSubscriptionRepository {
  ProductSubscriptionRepository({SupabaseClient? client}) : _client = client ?? SupabaseService.client;
  final SupabaseClient? _client;
  SupabaseClient get _db { final c=_client; if(c==null) throw StateError('Supabase unavailable'); return c; }

  Future<List<ProductSubscription>> listMine() async {
    final res = await _db.rpc('list_my_customer_product_subscriptions');
    final list = (res as List?) ?? const [];
    return list.whereType<Map>().map((e)=>ProductSubscription.fromJson(Map<String,dynamic>.from(e))).toList();
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _db.rpc('create_customer_product_subscription', params: {'p_payload': payload});
  }

  Future<void> pause(String id) async => _db.rpc('pause_my_customer_product_subscription', params: {'p_id': id});
  Future<void> resume(String id) async => _db.rpc('resume_my_customer_product_subscription', params: {'p_id': id});
  Future<void> cancel(String id) async => _db.rpc('cancel_my_customer_product_subscription', params: {'p_id': id});
}
