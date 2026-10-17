import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';

/// Coupons are server-validated. There is no seeded offline list: any attempt
/// to read or validate coupons without a Supabase backend must fail closed with
/// a [StateError]. Client-side guards (empty code) still surface errors early.
void main() {
  test('empty coupon code throws an ArgumentError', () async {
    const repository = CouponRepositoryImpl();
    await expectLater(
      repository.validate(code: '   ', subtotal: 50),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('active coupons require a configured backend', () async {
    const repository = CouponRepositoryImpl();
    await expectLater(
      repository.activeCoupons(),
      throwsA(isA<StateError>()),
    );
  });

  test('coupon validation requires a configured backend', () async {
    const repository = CouponRepositoryImpl();
    await expectLater(
      repository.validate(code: 'WELCOME200', subtotal: 50),
      throwsA(isA<StateError>()),
    );
  });
}
