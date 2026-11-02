import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';

/// Anonymous callers can list active offers, but validation is a
/// signed-in-only wrapper. Authenticated validation and usage limits are
/// covered by the database acceptance suite.
///
/// Run against the live project on 2026-11-02 with only
/// `--dart-define=SCHEMAS_EXPOSED=true` (the public project key is a compiled
/// default). It asserted the deleted `DEMO10` offer until then, so it failed on
/// a correct database: 136 removed the demo catalogue and the owner re-entered
/// real offers. What is checked now is the mapping and the role boundary, which
/// hold for any seed.
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

    expect(
      coupons,
      isNotEmpty,
      reason: 'catalog.coupons must carry at least one live offer',
    );
    expect(coupons.every((coupon) => coupon.code.trim().isNotEmpty), isTrue);
    expect(
      coupons.every((coupon) => coupon.discountValue > 0),
      isTrue,
      reason: 'discounts must be numeric rules, not display text',
    );
    expect(
      coupons.map((coupon) => coupon.code).toSet().length,
      coupons.length,
      reason: 'two offers with one code cannot both be applied',
    );

    // The same offer the read just returned, refused to the role that may not
    // redeem it: the rejection is a grant (42501), not a "not found".
    await expectLater(
      repository.validate(code: coupons.first.code, subtotal: 100),
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
