import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// حذف إشعار قائم.
class DeleteNotificationUseCase {
  const DeleteNotificationUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<NotificationMutationOutcome> call(String notificationId) =>
      _repository.deleteNotification(notificationId);
}
