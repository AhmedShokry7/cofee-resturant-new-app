import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/loyalty/data/repositories/loyalty_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';

/// Anonymous loyalty access must expose reference data while keeping the
/// account ledger unreachable. Authenticated ledger behaviour is covered by
/// the database acceptance suite.
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');
  const needsSetup =
      'Needs --dart-define SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and '
      'SCHEMAS_EXPOSED=true';

  final String? skip =
      (!AppConfig.isSupabaseConfigured || !schemasExposed) ? needsSetup : null;

  setUpAll(() async {
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    await Supabase.instance.client.auth.signOut();
  });

  test('anonymous callers see rules and rewards, but no wallet', () async {
    final repository = LoyaltyRepositoryImpl(
      catalog: SupabaseProductRepository(),
    );

    final catalog = await repository.loadCatalog();
    expect(catalog.currencyCode, 'SAR');
    expect(catalog.rules, isNotEmpty);
    expect(
      catalog.rewards.map((reward) => reward.pointsCost),
      [150, 180, 200, 250, 300, 400],
    );
    expect(
      catalog.rewards.every((reward) => reward.product.name.isNotEmpty),
      isTrue,
    );

    expect(await repository.loadWallet(), isNull);
    await expectLater(
      repository.redeemReward(
        productId: catalog.rewards.first.product.id,
        branchId: '00000000-0000-4000-8000-000000000101',
      ),
      throwsA(isA<StateError>()),
    );
  }, skip: skip);
}
