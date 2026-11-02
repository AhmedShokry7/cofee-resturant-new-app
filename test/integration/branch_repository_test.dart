import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';

/// Branch selection is the key to branch pricing, availability, carts and
/// checkout. Anonymous callers must be able to list branches; nothing here
/// writes.
///
/// Run against the live project on 2026-11-02 with only
/// `--dart-define=SCHEMAS_EXPOSED=true`. It used to assert the demo seed's
/// `MAIN`/`JEDDAH` pair, which 136 deleted, so it failed on a correct database
/// that now holds the owner's real branches. The invariants below - one row per
/// branch, every field mapped, ordered, active-only - hold for any seed.
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

  test('anonymous callers can list the active branches', () async {
    const repository = BranchRepositoryImpl();
    final branches = await repository.activeBranches();

    expect(
      branches,
      isNotEmpty,
      reason: 'core.branches must carry at least one active branch',
    );
    expect(branches.every((branch) => branch.id.isNotEmpty), isTrue);
    expect(branches.every((branch) => branch.code.trim().isNotEmpty), isTrue);
    expect(
      branches.map((branch) => branch.id).toSet().length,
      branches.length,
      reason: 'the menu keys its state on the branch id',
    );
    expect(branches.every((branch) => branch.nameEn.trim().isNotEmpty), isTrue);
    expect(
      branches.every((branch) => branch.nameAr.trim().isNotEmpty),
      isTrue,
      reason: 'the branch picker shows Arabic first',
    );
    expect(
      branches.map((branch) => branch.code).toList(),
      branches.map((branch) => branch.code).toList()..sort(),
      reason: 'the list is ordered, so the picker cannot shuffle between runs',
    );
  }, skip: skip);
}
