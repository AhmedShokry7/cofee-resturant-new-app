import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';

void main() {
  test('offline coupons mirror the seeded numeric rules', () async {
    const repository = CouponRepositoryImpl();
    final coupons = await repository.activeCoupons();

    expect(coupons.map((coupon) => coupon.code), [
      'WELCOME200',
      'COFFEE20',
      'COLD50',
      'LOYAL10',
    ]);
    expect(coupons.first.discount, '50% off up to \$40.00');
  });

  test('offline validation caps the discount and enforces minimums', () async {
    const repository = CouponRepositoryImpl();

    final capped = await repository.validate(code: 'welcome200', subtotal: 100);
    expect(capped.discount, 40);

    await expectLater(
      repository.validate(code: 'WELCOME200', subtotal: 20),
      throwsA(isA<CouponRejectedException>()),
    );
    await expectLater(
      repository.validate(code: 'UNKNOWN', subtotal: 100),
      throwsA(isA<CouponRejectedException>()),
    );
  });
}
