import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';

/// Branch selection is the key to branch pricing, availability, carts and
/// checkout. Anonymous callers must be able to list branches; nothing here
/// writes.
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

  test('anonymous callers can list the active branches', () async {
    const repository = BranchRepositoryImpl();
    final branches = await repository.activeBranches();

    expect(branches.map((branch) => branch.code), ['MAIN', 'JEDDAH']);
    expect(
      branches.map((branch) => branch.nameEn),
      ['Main Branch', 'Jeddah Branch'],
    );
    expect(branches.every((branch) => branch.id.isNotEmpty), isTrue);
  }, skip: skip);
}
