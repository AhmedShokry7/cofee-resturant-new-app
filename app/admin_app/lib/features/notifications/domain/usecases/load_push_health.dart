import 'package:admin_app/features/notifications/domain/entities/admin_push_health.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// قراءة حالة إعداد الدفع (Push).
class LoadPushHealthUseCase {
  const LoadPushHealthUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminPushHealth> call() => _repository.loadPushHealth();
}
