import 'package:admin_app/features/notifications/domain/entities/admin_notification_metrics.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// قراءة ملخص مؤشرات الإشعارات.
class LoadMetricsUseCase {
  const LoadMetricsUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminNotificationMetrics> call() => _repository.loadMetrics();
}
