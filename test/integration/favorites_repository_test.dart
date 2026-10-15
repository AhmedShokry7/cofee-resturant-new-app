import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';

/// The guest path must stay usable when Supabase is configured but no session
/// exists. Server mirroring is covered by the database acceptance probe, which
/// can exercise owned-row RLS as real authenticated users.
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

  test('anonymous favourites use device storage only', () async {
    const repository = FavoritesRepositoryImpl();

    await repository.addFavorite('1');
    expect(await repository.loadLocalIds(), {'1'});

    await repository.removeFavorite('1');
    expect(await repository.loadLocalIds(), isEmpty);
  }, skip: skip);
}
