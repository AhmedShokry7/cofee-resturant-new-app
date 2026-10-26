import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// قراءة العملاء المطابقين للبحث في مُنشئ الإشعار.
class LoadCustomersUseCase {
  const LoadCustomersUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<List<AdminNotificationComposerCustomer>> call({
    String? search,
    int limit = 20,
  }) => _repository.loadCustomers(search: search, limit: limit);
}
