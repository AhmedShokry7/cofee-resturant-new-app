import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// إرسال إشعار إلى جمهور محدد.
class SendNotificationUseCase {
  const SendNotificationUseCase(this._repository);

  final NotificationsRepository _repository;

  Future<AdminSendResult> call({
    required AdminNotificationType type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required AdminNotificationAudience audience,
    String? customerId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) => _repository.sendNotification(
    type: type,
    titleAr: titleAr,
    titleEn: titleEn,
    bodyAr: bodyAr,
    bodyEn: bodyEn,
    audience: audience,
    customerId: customerId,
    payload: payload,
  );
}
