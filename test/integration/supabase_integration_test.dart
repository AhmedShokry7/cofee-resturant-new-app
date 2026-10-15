import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live integration checks against the real Supabase project.
///
/// Everything is off by default so `flutter test` stays offline-safe and green.
/// Enable the database-dependent half explicitly, and only once the Supabase
/// dashboard setting has been applied:
///
///   flutter test test/integration/supabase_integration_test.dart \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=... \
///     --dart-define=TEST_USER_EMAIL=... \
///     --dart-define=TEST_USER_PASSWORD=... \
///     --dart-define=SCHEMAS_EXPOSED=true
///
/// Only the publishable key is used. The service_role key is never passed to a
/// test, because a result obtained with it would prove nothing about RLS.
void main() {
  const email = String.fromEnvironment('TEST_USER_EMAIL');
  const password = String.fromEnvironment('TEST_USER_PASSWORD');
  // Set only after Dashboard -> Settings -> API -> Exposed schemas is done.
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');

  const needsCredentials =
      'Needs --dart-define SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, '
      'TEST_USER_EMAIL, TEST_USER_PASSWORD';

  const needsSchemas =
      'Application schemas are not exposed to PostgREST. Set once in the '
      'Supabase dashboard: Settings -> API -> Exposed schemas -> add '
      'identity, core, catalog, orders, inventory, payments, loyalty, '
      'marketing, engagement. Then pass --dart-define=SCHEMAS_EXPOSED=true. '
      'There is no SQL alternative: managed PostgREST reads its config from '
      'the platform, not from a role setting.';

  final String? credentialSkip =
      (AppConfig.isSupabaseConfigured && email.isNotEmpty) ? null : needsCredentials;

  final String? dbSkip = credentialSkip ?? (schemasExposed ? null : needsSchemas);

  group('Supabase live integration', () {
    late SupabaseClient client;

    setUpAll(() async {
      if (credentialSkip != null) return;
      // supabase_flutter persists the session through SharedPreferences, which
      // has no platform implementation in a headless test.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final initialised = await SupabaseService.init();
      expect(initialised, isNotNull,
          reason: 'SupabaseService.init() must succeed when configured');
      client = SupabaseService.client;
    });

    test('client initialises with a publishable key only', () {
      expect(client, isNotNull);
      expect(AppConfig.supabasePublishableKey.isNotEmpty, isTrue);
      // A publishable key is sb_publishable_*. A JWT here would mean a
      // service_role key leaked into the client.
      expect(AppConfig.supabasePublishableKey.startsWith('eyJ'), isFalse,
          reason: 'a publishable key is sb_publishable_*, not a JWT');
    }, skip: credentialSkip);

    test('signs in with real credentials', () async {
      final response =
          await client.auth.signInWithPassword(email: email, password: password);
      expect(response.user, isNotNull);
      expect(response.user!.email, email);
      expect(response.session, isNotNull,
          reason: 'a real session is what makes RLS meaningful');
    }, skip: credentialSkip);

    test('currentUser() reflects the real session', () async {
      await client.auth.signInWithPassword(email: email, password: password);
      expect(client.auth.currentUser, isNotNull);
      expect(client.auth.currentSession, isNotNull);
    }, skip: credentialSkip);

    // --- require the exposed-schemas setting ------------------------------

    test('anon can read the public catalogue', () async {
      final rows = await client.from('catalog.categories').select('id, slug');
      expect(rows.length, greaterThan(0),
          reason: 'seed_02_catalog.sql should have loaded categories');
    }, skip: dbSkip);

    test('anon cannot read customer tables', () async {
      Object? error;
      try {
        await client.from('identity.profiles').select('id');
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull,
          reason: 'reading identity.profiles as anon must be refused');
    }, skip: dbSkip);

    test('cannot reach the ai schema from a client role', () async {
      Object? error;
      try {
        await client.from('ai.product_knowledge').select('product_id');
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull,
          reason: 'ai must never be reachable from anon or authenticated');
    }, skip: dbSkip);

    test('searches in Arabic through the RPC', () async {
      await client.auth.signInWithPassword(email: email, password: password);
      final rows = await client.rpc('search_products', params: {
        'p_query': 'لاتيه',
        'p_page_size': 5,
      });
      expect(rows, isA<List>());
      final names = (rows as List)
          .map((r) => (r as Map)['name_en'])
          .whereType<String>()
          .toList();
      expect(names, isNotEmpty,
          reason: 'the Arabic alias table should make "لاتيه" resolve to Latte');
      expect(names.first, 'Latte');
    }, skip: dbSkip);

    test('reads the customer own profile, and only their own', () async {
      await client.auth.signInWithPassword(email: email, password: password);
      final me = client.auth.currentUser;
      final rows =
          await client.from('identity.profiles').select('id, full_name');
      expect(rows.length, 1, reason: 'RLS should return exactly the caller');
      expect(rows.first['id'], me!.id);
    }, skip: dbSkip);

    test('cannot write a staff record', () async {
      await client.auth.signInWithPassword(email: email, password: password);
      Object? error;
      try {
        await client.from('identity.staff_members').insert({
          'user_id': client.auth.currentUser!.id,
          'full_name': 'Escalation attempt',
          'email': 'escalation@test.local',
        });
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull,
          reason: 'a customer must not be able to grant themselves staff');
    }, skip: dbSkip);
  });
}