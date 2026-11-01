import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';

/// Integration checks for the `public.set_default_address` bridge.
///
/// Read-only/permission checks run with SCHEMAS_EXPOSED=true. Mutating checks
/// are additionally gated by ADDRESS_MUTATION_TESTS=true and must only be
/// enabled against a local or staging database, never production.
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');
  const allowMutations = bool.fromEnvironment('ADDRESS_MUTATION_TESTS');

  const primaryEmail = String.fromEnvironment('TEST_USER_EMAIL');
  const primaryPassword = String.fromEnvironment('TEST_USER_PASSWORD');
  const secondaryEmail = String.fromEnvironment('TEST_USER_B_EMAIL');
  const secondaryPassword = String.fromEnvironment('TEST_USER_B_PASSWORD');

  const needsSchemas =
      'Needs --dart-define SCHEMAS_EXPOSED=true after exposing public.';
  const needsPrimaryCredentials =
      'Needs --dart-define TEST_USER_EMAIL and TEST_USER_PASSWORD.';
  const needsMutationOptIn =
      'Needs --dart-define ADDRESS_MUTATION_TESTS=true against a non-production database.';

  final String? schemaSkip = schemasExposed ? null : needsSchemas;
  final String? primaryCredentialSkip =
      (primaryEmail.isNotEmpty && primaryPassword.isNotEmpty)
          ? null
          : needsPrimaryCredentials;
  final String? mutationSkip = (schemaSkip ?? primaryCredentialSkip) ??
      (allowMutations ? null : needsMutationOptIn);

  group('address default bridge', () {
    late SupabaseClient client;

    setUpAll(() async {
      if (schemaSkip != null) return;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await SupabaseService.init();
      client = SupabaseService.client;
    });

    test('anonymous callers cannot set a default address', () async {
      Object? error;
      try {
        await client.rpc(
          'set_default_address',
          params: <String, dynamic>{
            'p_address_id': '00000000-0000-0000-0000-000000000000',
          },
        );
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull,
          reason: 'anon must not be able to change a default address');
      expect(error, isA<PostgrestException>());
    }, skip: schemaSkip);

    test('bridge rejects an address owned by another user', () async {
      if (mutationSkip != null || secondaryEmail.isEmpty) return;

      await client.auth.signInWithPassword(
        email: primaryEmail,
        password: primaryPassword,
      );
      final primaryRepo = SupabaseAddressRepository(client: client);

      final secondaryClient = SupabaseClient(
        AppConfig.supabaseUrl,
        AppConfig.supabasePublishableKey,
      );
      await secondaryClient.auth.signInWithPassword(
        email: secondaryEmail,
        password: secondaryPassword,
      );
      final secondaryRepo = SupabaseAddressRepository(client: secondaryClient);

      final secondaryAddress = await secondaryRepo.addAddress(
        label: 'bridge-test-secondary',
        details: 'secondary owner address',
        isDefault: true,
      );

      Object? error;
      try {
        await primaryRepo.setDefaultAddress(secondaryAddress.id);
      } catch (e) {
        error = e;
      }

      await secondaryRepo.removeAddress(secondaryAddress.id);
      await secondaryClient.auth.signOut();

      expect(error, isNotNull,
          reason: 'an address owned by user B must not be mutable by user A');
    }, skip: mutationSkip);

    test('owner can set an address as default', () async {
      if (mutationSkip != null) return;

      await client.auth.signInWithPassword(
        email: primaryEmail,
        password: primaryPassword,
      );
      final repository = SupabaseAddressRepository(client: client);

      final original = await repository.listAddresses();
      final originalDefaultId = original
          .firstWhere(
            (address) => address.isDefault,
            orElse: () => original.isEmpty ? const AddressModel(
                  id: '',
                  label: '',
                  details: '',
                ) : original.first,
          )
          .id;

      final created = await repository.addAddress(
        label: 'bridge-test-owner',
        details: 'owner default test address',
      );

      await repository.setDefaultAddress(created.id);

      final after = await repository.listAddresses();
      final updated = after.firstWhere((address) => address.id == created.id);
      expect(updated.isDefault, isTrue);

      final defaults = after.where((address) => address.isDefault).toList();
      expect(defaults.length, lessThanOrEqualTo(1),
          reason: 'at most one default address should remain');

      // Best-effort restoration; failures here do not invalidate the assertion.
      if (originalDefaultId.isNotEmpty && originalDefaultId != created.id) {
        try {
          await repository.setDefaultAddress(originalDefaultId);
        } catch (_) {}
      }
      await repository.removeAddress(created.id);
    }, skip: mutationSkip);
  });
}
