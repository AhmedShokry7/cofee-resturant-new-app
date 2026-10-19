import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/dashboard/data/models/dashboard_stats.dart';

class DashboardRepository {
  DashboardRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<DashboardStats> load({
    required bool includeOrders,
    required bool includeProducts,
    required bool includeCustomers,
    required bool includeBranches,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

    int? todayOrders;
    int? activeOrders;
    int? totalOrders;
    double? todayRevenue;
    List<RecentOrder> recentOrders = const <RecentOrder>[];

    if (includeOrders) {
      totalOrders = await _supabase.from('orders').count();

      activeOrders = await _supabase
          .from('orders')
          .count()
          .not('status', 'in', '(completed,cancelled)');

      final todayRows = await _supabase
          .from('orders')
          .select('grand_total')
          .gte('placed_at', startOfDay.toIso8601String());

      todayOrders = todayRows.length;
      todayRevenue = _sumMoney(todayRows, 'grand_total');

      final recentRows = await _supabase
          .from('orders')
          .select(
            'id, order_number, status, grand_total, placed_at, fulfillment_type',
          )
          .order('placed_at', ascending: false)
          .limit(6);

      recentOrders = recentRows.map(RecentOrder.fromJson).toList();
    }

    int? activeProducts;
    if (includeProducts) {
      activeProducts = await _supabase
          .from('products')
          .count()
          .eq('is_active', true)
          .isFilter('archived_at', null);
    }

    int? customers;
    if (includeCustomers) {
      customers = await _supabase.from('profiles').count();
    }

    int? activeBranches;
    if (includeBranches) {
      activeBranches = await _supabase
          .from('branches')
          .count()
          .eq('is_active', true);
    }

    return DashboardStats(
      todayOrders: todayOrders,
      todayRevenue: todayRevenue,
      activeOrders: activeOrders,
      totalOrders: totalOrders,
      activeProducts: activeProducts,
      customers: customers,
      activeBranches: activeBranches,
      recentOrders: recentOrders,
    );
  }

  double _sumMoney(List<Map<String, dynamic>> rows, String column) {
    var total = 0.0;
    for (final row in rows) {
      final value = row[column];
      if (value is num) {
        total += value.toDouble();
      } else {
        total += double.tryParse('$value') ?? 0;
      }
    }
    return total;
  }
}
