import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// إعادة إرسال إشعار قائم.
class ResendNotificationUseCase {
  const ResendNotificationUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminResendResult> call(String notificationId) =>
      _repository.resendNotification(notificationId);
}
