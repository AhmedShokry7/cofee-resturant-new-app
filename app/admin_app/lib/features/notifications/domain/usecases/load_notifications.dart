import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// قراءة صفحة إشعارات اللوحة مع فلاترها.
class LoadNotificationsUseCase {
  const LoadNotificationsUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminNotificationPage> call({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    String? source,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 0,
    int pageSize = AdminNotificationsPaging.pageSize,
  }) => _repository.loadNotifications(
    search: search,
    type: type,
    isRead: isRead,
    pushState: pushState,
    source: source,
    dateFrom: dateFrom,
    dateTo: dateTo,
    page: page,
    pageSize: pageSize,
  );
}
