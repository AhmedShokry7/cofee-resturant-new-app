import 'package:admin_app/features/dashboard/data/models/dashboard_stats.dart';

enum DashboardStatus { loading, ready, error }

class DashboardState {
  const DashboardState({
    required this.status,
    this.stats,
    this.errorMessage,
  });

  final DashboardStatus status;
  final DashboardStats? stats;
  final String? errorMessage;
}
