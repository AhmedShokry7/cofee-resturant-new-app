import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';

AdminSubscription _subscription({
  String status = 'active',
  DateTime? startsAt,
  DateTime? endsAt,
  int entitled = 10,
  int used = 4,
  int carried = 2,
  int reserved = 0,
  String? nameAr = 'الخطة الذهبية',
  String? nameEn = 'Gold plan',
  String? code = 'gold',
}) => AdminSubscription(
  id: 's1',
  status: status,
  startsAt: startsAt,
  endsAt: endsAt,
  cupsEntitled: entitled,
  cupsUsed: used,
  cupsCarriedOver: carried,
  cupsReserved: reserved,
  planNameAr: nameAr,
  planNameEn: nameEn,
  planCode: code,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('fromJson', () {
    test('reads the enriched admin_subscriptions row', () {
      final subscription = AdminSubscription.fromJson(<String, dynamic>{
        'id': 'abc',
        'customer_name': 'Sara Ali',
        'customer_email': 'sara@example.com',
        'customer_phone': '+966500000000',
        'plan_code': 'gold',
        'plan_name_ar': 'الذهبية',
        'plan_name_en': 'Gold',
        'plan_price': 120,
        'currency_code': 'SAR',
        'plan_duration_days': 30,
        'status': 'active',
        'starts_at': '2026-10-01T08:00:00Z',
        'ends_at': '2026-10-31T08:00:00Z',
        'cups_entitled': 30,
        'cups_used': 8,
        'cups_carried_over': 2,
        'cups_reserved': 1,
        'bonus_balance': 15.5,
        'auto_renew': true,
        'payment_reference': 'pay_123',
        'usage_count': 6,
        'last_used_at': '2026-10-20T09:30:00Z',
      });

      expect(subscription.id, 'abc');
      expect(subscription.customerPhone, '+966500000000');
      expect(subscription.planCode, 'gold');
      expect(subscription.planPrice, 120);
      expect(subscription.planDurationDays, 30);
      expect(subscription.cupsTotal, 32);
      expect(subscription.cupsAvailable, 23);
      expect(subscription.autoRenew, isTrue);
      expect(subscription.usageCount, 6);
      expect(subscription.lastUsedAt, DateTime.utc(2026, 10, 20, 9, 30));
      expect(subscription.endsAt, DateTime.utc(2026, 10, 31, 8));
    });

    test('missing numbers default to zero instead of crashing', () {
      final subscription = AdminSubscription.fromJson(<String, dynamic>{
        'id': 'abc',
        'status': 'pending_payment',
      });

      expect(subscription.cupsEntitled, 0);
      expect(subscription.cupsUsed, 0);
      expect(subscription.cupsReserved, 0);
      expect(subscription.bonusBalance, 0);
      expect(subscription.autoRenew, isFalse);
      expect(subscription.startsAt, isNull);
      expect(subscription.endsAt, isNull);
    });
  });

  group('cups', () {
    test('total includes carried-over cups and available subtracts usage', () {
      final subscription = _subscription(
        entitled: 10,
        used: 4,
        carried: 2,
        reserved: 1,
      );

      expect(subscription.cupsTotal, 12);
      expect(subscription.cupsAvailable, 7);
      expect(subscription.cupsProgress, closeTo(4 / 12, 0.0001));
    });

    test('available never drops below zero', () {
      final subscription = _subscription(entitled: 2, used: 5, carried: 0);

      expect(subscription.cupsAvailable, 0);
      expect(subscription.cupsProgress, 1);
    });

    test('a plan with no cups reports no progress', () {
      final subscription = _subscription(entitled: 0, used: 0, carried: 0);

      expect(subscription.cupsTotal, 0);
      expect(subscription.cupsProgress, 0);
    });
  });

  group('period', () {
    test('an active subscription inside the week is expiring soon', () {
      final subscription = _subscription(
        endsAt: DateTime.now().add(const Duration(days: 3)),
      );

      expect(subscription.isActive, isTrue);
      expect(subscription.isExpiringSoon, isTrue);
      expect(subscription.daysRemaining, 3);
    });

    test('an active subscription outside the week is not expiring soon', () {
      final subscription = _subscription(
        endsAt: DateTime.now().add(const Duration(days: 20)),
      );

      expect(subscription.isExpiringSoon, isFalse);
      expect(subscription.daysRemaining, 20);
    });

    test('a finished period reports zero days left', () {
      final subscription = _subscription(
        endsAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(subscription.isExpiringSoon, isFalse);
      expect(subscription.daysRemaining, 0);
    });

    test('a subscription that never started has no remaining days', () {
      final subscription = _subscription(status: 'pending_payment');

      expect(subscription.daysRemaining, isNull);
      expect(subscription.isExpiringSoon, isFalse);
    });
  });

  group('cancellation', () {
    test(
      'active and pending subscriptions without reservations can cancel',
      () {
        expect(_subscription().isCancellable, isTrue);
        expect(_subscription(status: 'pending_payment').isCancellable, isTrue);
      },
    );

    test('reserved cups block cancellation', () {
      final subscription = _subscription(reserved: 1);

      expect(subscription.isActive, isTrue);
      expect(subscription.isCancellable, isFalse);
    });

    test('expired and cancelled subscriptions cannot cancel again', () {
      expect(_subscription(status: 'expired').isCancellable, isFalse);
      expect(_subscription(status: 'cancelled').isCancellable, isFalse);
    });
  });

  group('plan name', () {
    test('follows the language and falls back to the other translation', () {
      final subscription = _subscription();

      expect(subscription.planNameFor(AppLanguage.english), 'Gold plan');
      expect(subscription.planNameFor(AppLanguage.arabic), 'الخطة الذهبية');
      expect(
        _subscription(nameEn: null).planNameFor(AppLanguage.english),
        'الخطة الذهبية',
      );
      expect(
        _subscription(
          nameEn: ' ',
          nameAr: null,
        ).planNameFor(AppLanguage.english),
        'gold',
      );
    });

    test('returns an empty string when the plan has no data at all', () {
      final subscription = _subscription(
        nameAr: null,
        nameEn: null,
        code: null,
      );

      expect(subscription.planNameFor(AppLanguage.english), '');
    });
  });
}
