import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';

/// Anonymous callers can list active offers, but validation is a
/// signed-in-only wrapper. Authenticated validation and usage limits are
/// covered by the database acceptance suite.
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');
  const needsSetup =
      'Needs --dart-define SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and '
      'SCHEMAS_EXPOSED=true';

  final String? skip = (!AppConfig.isSupabaseConfigured || !schemasExposed)
      ? needsSetup
      : null;

  setUpAll(() async {
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    await Supabase.instance.client.auth.signOut();
  });

  test('anonymous callers list offers; validation needs sign-in', () async {
    const repository = CouponRepositoryImpl();
    final coupons = await repository.activeCoupons();

    expect(coupons.map((coupon) => coupon.code), containsAll(['DEMO10']));
    expect(
      coupons.every((coupon) => coupon.discountValue > 0),
      isTrue,
      reason: 'discounts must be numeric rules, not display text',
    );

    await expectLater(
      repository.validate(code: 'DEMO10', subtotal: 100),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          '42501',
        ),
      ),
    );
  }, skip: skip);
}
