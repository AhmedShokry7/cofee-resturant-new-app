import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';

/// Cover for the coupon behaviour a customer reported as "the coupon disappears
/// when I apply it".
///
/// The rule itself was never wrong: a redemption is written only when an order
/// completes, and `per_user_limit` is per customer. What was wrong is that the
/// list could not show any of that, so a spent code looked identical to a fresh
/// one until checkout refused it with a raw English message.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  CouponModel coupon({
    int usedCount = 0,
    int? perUserLimit = 3,
    int? usageLimit,
    int totalUsed = 0,
  }) => CouponModel(
    id: 'c1',
    code: 'WELCOME200',
    discountValue: 50,
    usedCount: usedCount,
    perUserLimit: perUserLimit,
    usageLimit: usageLimit,
    totalUsed: totalUsed,
  );

  group('remainingUses', () {
    test('is the limit minus what the customer already used', () {
      expect(coupon(perUserLimit: 3).remainingUses, 3);
      expect(coupon(usedCount: 1, perUserLimit: 3).remainingUses, 2);
      expect(coupon(usedCount: 2, perUserLimit: 3).remainingUses, 1);
    });

    test('is zero, never negative, once the allowance is spent', () {
      expect(coupon(usedCount: 3, perUserLimit: 3).remainingUses, 0);
      expect(coupon(usedCount: 9, perUserLimit: 3).remainingUses, 0);
    });

    test('is unknown when the server reported no limit', () {
      expect(coupon(perUserLimit: null).remainingUses, isNull);
    });
  });

  group('isExhaustedForMe', () {
    test('false while the customer has uses left', () {
      expect(coupon(usedCount: 0, perUserLimit: 1).isExhaustedForMe, isFalse);
    });

    test('true once the per-user allowance is spent', () {
      expect(coupon(usedCount: 1, perUserLimit: 1).isExhaustedForMe, isTrue);
    });

    test('true when other customers have burned the global allowance', () {
      // usage_limit is null on every seeded coupon, which means unlimited and
      // must never read as "exhausted".
      expect(
        coupon(usageLimit: null, totalUsed: 10_000).isExhaustedForMe,
        isFalse,
      );
      expect(
        coupon(usageLimit: 100, totalUsed: 100).isExhaustedForMe,
        isTrue,
      );
      expect(
        coupon(usageLimit: 100, totalUsed: 99).isExhaustedForMe,
        isFalse,
      );
    });

    test('unknown counters do not mark a coupon unavailable', () {
      expect(coupon(perUserLimit: null).isExhaustedForMe, isFalse);
    });
  });

  group('server rejection messages', () {
    test('every reason validate_coupon can return is translated', () {
      // These are the literal strings marketing.validate_coupon sends back.
      const reasons = [
        'code not valid',
        'code expired',
        'minimum order not reached',
        'code fully used',
        'you already used this code',
        'code does not apply to your items',
      ];
      for (final reason in reasons) {
        final english = S.couponRejected(reason);
        expect(english, isNot(reason), reason: reason);
        expect(english, isNotEmpty, reason: reason);
      }
    });

    test('the message follows the app language', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      final english = S.couponRejected('you already used this code');
      AppLocale.instance.debugSet(AppLanguage.arabic);
      final arabic = S.couponRejected('you already used this code');

      expect(arabic, isNot(english));
      expect(arabic, isNot(contains('code')));
      expect(RegExp('[\u0600-\u06FF]').hasMatch(arabic), isTrue);
    });

    test('an unknown reason still yields a safe message, not raw text', () {
      expect(
        S.couponRejected('some new server sentence'),
        isNot(contains('some new server sentence')),
      );
    });
  });

  group('withUsage', () {
    test('carries the counters over and keeps the rule', () {
      final base = CouponModel(
        id: 'c1',
        code: 'WELCOME200',
        titleEn: 'Welcome discount',
        discountType: 'percentage',
        discountValue: 50,
        maxDiscount: 40,
        minOrderAmount: 30,
      );
      final merged = base.withUsage(
        CouponModel(
          id: 'c1',
          code: 'WELCOME200',
          usedCount: 1,
          perUserLimit: 1,
          usageLimit: null,
          totalUsed: 4,
        ),
      );

      expect(merged.titleEn, 'Welcome discount');
      expect(merged.discountValue, 50);
      expect(merged.maxDiscount, 40);
      expect(merged.minOrderAmount, 30);
      expect(merged.usedCount, 1);
      expect(merged.remainingUses, 0);
      expect(merged.isExhaustedForMe, isTrue);
    });
  });
}