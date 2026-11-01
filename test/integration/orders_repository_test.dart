import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/supabase_order_repository.dart';

/// Guards the order boundary: anonymous callers must be asked to sign in
/// before Supabase is ever queried.
///
/// This intentionally creates no orders. Authenticated order placement and
/// cancellation are already covered by the database acceptance suite, which can
/// roll its test users and orders back.
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

  test('anonymous order reads and cancellation require sign-in', () async {
    final OrdersRepository repository = SupabaseOrdersRepository();

    await expectLater(
      repository.listOrders(),
      throwsA(isA<OrderSignInRequiredException>()),
    );
    await expectLater(
      repository.cancelOrder('00000000-0000-0000-0000-000000000000'),
      throwsA(isA<OrderSignInRequiredException>()),
    );
  }, skip: skip);
}
