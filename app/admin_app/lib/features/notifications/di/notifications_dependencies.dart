import 'package:admin_app/features/notifications/data/repositories/admin_notifications_repository.dart';
import 'package:admin_app/features/notifications/domain/repositories/notifications_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الإشعارات داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class NotificationsDependencies {
  NotificationsDependencies._();

  static NotificationsRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static NotificationsRepository get repository =>
      _repository ??= AdminNotificationsRepository();
}
