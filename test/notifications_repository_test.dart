import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';

/// Notifications come from the server and require authentication. The model
/// should resolve bilingual titles, bodies and relative times. Without a backend
/// the repository must fail closed (no invented rows for guests).
void main() {
  test('database rows map to bilingual notifications with relative time', () {
    AppLocale.instance.debugSet(AppLanguage.english);
    final createdAt = DateTime.now().subtract(const Duration(hours: 3));
    final notification = NotificationModel.fromDatabase({
      'id': 'notification-1',
      'type': 'order_status',
      'title_ar': 'طلبك في الطريق',
      'title_en': 'Your order is on the way',
      'body_ar': 'تابع طلبك الآن',
      'body_en': 'Track it now',
      'is_read': false,
      'created_at': createdAt.toUtc().toIso8601String(),
    });

    expect(notification.title, isNotEmpty);
    expect(notification.body, isNotEmpty);
    expect(notification.isRead, isFalse);
    expect(notification.time, '3h ago');
  });

  test('without a backend notifications are not invented for guests', () async {
    const repository = NotificationsRepositoryImpl();
    await expectLater(
      repository.listNotifications(),
      throwsA(isA<StateError>()),
    );
  });
}
