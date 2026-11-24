import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_bulk_delete.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// يعيد معرّفات الإشعارات القابلة للحذف التي تطابق الفلاتر الحالية في كل الصفحات.
class LoadMatchingDeletableIdsUseCase {
  const LoadMatchingDeletableIdsUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminNotificationMatchingIds> call({
    String? search,
    AdminNotificationType? type,
    bool? isRead,
    String? pushState,
    String? source,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _repository.loadMatchingDeletableIds(
    search: search,
    type: type,
    isRead: isRead,
    pushState: pushState,
    source: source,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );
}
