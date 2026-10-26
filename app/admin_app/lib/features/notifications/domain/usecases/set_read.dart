import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// تعليم الإشعار مقروءًا أو غير مقروء.
class SetReadUseCase {
  const SetReadUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<NotificationMutationOutcome> call(String notificationId, bool read) =>
      _repository.setRead(notificationId, read);
}
