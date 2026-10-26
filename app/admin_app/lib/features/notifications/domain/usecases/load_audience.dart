import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// قراءة تقدير حجم الجمهور قبل الإرسال.
class LoadAudienceUseCase {
  const LoadAudienceUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminAudienceEstimate> call({
    required AdminNotificationType type,
    required AdminNotificationAudience audience,
    String? customerId,
  }) => _repository.loadAudience(
    type: type,
    audience: audience,
    customerId: customerId,
  );
}
