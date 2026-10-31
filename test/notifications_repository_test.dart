import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/features/coupon/presentation/views/coupon_page.dart';
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

  test(
    'a campaign row carries its picture and its screen from the payload',
    () {
      final notification = NotificationModel.fromDatabase({
        'id': 'campaign-1',
        'type': 'promo',
        'title_en': 'Winter offer',
        'body_en': 'Half price today',
        'payload': {
          'image_url': 'https://tenant.supabase.co/storage/v1/object/public/product-images/products/notifications/winter.png',
          'destination': 'offers',
        },
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(notification.imageUrl, isNotNull);
      expect(notification.destination, 'offers');
      expect(
        routeForNotification(
          relatedEntityType: notification.relatedEntityType,
          type: notification.type,
          destination: notification.destination,
        ),
        CouponPage.routeName,
      );
    },
  );

  test('a payload that is not a url or not a code is dropped', () {
    final row = NotificationModel.fromDatabase({
      'id': 'campaign-2',
      'type': 'system',
      'title_en': 'Note',
      'body_en': 'Body',
      'payload': {
        'image_url': 'file:///home/secret.png',
        'destination': '/orders?id=7',
      },
    });

    expect(row.imageUrl, isNull);
    expect(row.destination, isNull);
  });

  test('a row with no payload reads as a plain message', () {
    final row = NotificationModel.fromDatabase({
      'id': 'plain',
      'type': 'system',
      'title_en': 'Note',
      'body_en': 'Body',
    });

    expect(row.imageUrl, isNull);
    expect(row.destination, isNull);
    expect(imageUrlOf('products/a.png'), isNull);
    expect(destinationOf('orders page'), isNull);
  });

  test('without a backend notifications are not invented for guests', () async {
    const repository = NotificationsRepositoryImpl();
    await expectLater(
      repository.listNotifications(),
      throwsA(isA<StateError>()),
    );
  });
}
