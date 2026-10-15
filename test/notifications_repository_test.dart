import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/notifications/data/model/notification_model.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';

void main() {
  test('database rows map to bilingual notifications with relative time', () {
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

  test('guests receive an empty notification list, not invented rows', () async {
    const repository = NotificationsRepositoryImpl();
    await expectLater(
      repository.listNotifications(),
      completion(isEmpty),
    );
  });
}
