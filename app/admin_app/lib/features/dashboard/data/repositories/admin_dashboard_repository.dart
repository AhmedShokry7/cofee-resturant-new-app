import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/dashboard/data/models/admin_dashboard_metrics_model.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';

/// قراءة الأرقام من دالة القاعدة وكتابة الهدف منها، بلا استعلامات هنا.
class AdminDashboardRepository implements DashboardRepository {
  AdminDashboardRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<AdminDashboardMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_dashboard_metrics');
    if (response is Map) {
      return AdminDashboardMetricsModel.fromJson(
        Map<String, dynamic>.from(response),
      );
    }
    return AdminDashboardMetrics.empty;
  }

  @override
  Future<void> saveRevenueTarget(double? value) async {
    await _supabase.rpc(
      'admin_set_revenue_target',
      params: <String, dynamic>{'p_value': value},
    );
  }
}
