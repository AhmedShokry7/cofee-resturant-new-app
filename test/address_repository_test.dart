import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/addresses/data/repositories/address_repository.dart';

/// Regression cover for the insert payload.
///
/// `identity.customer_addresses.user_id` is NOT NULL with no default
/// (migration 003) and the owner-only RLS policy checks
/// `user_id = auth.uid()` (migration 019), so an insert without `user_id` is
/// always rejected and no address could ever be saved from the app.
void main() {
  group('addressPayload', () {
    test('carries the signed-in user id as user_id', () {
      final payload = addressPayload(
        userId: '11111111-1111-1111-1111-111111111111',
        label: 'Home',
        details: 'Street 1',
      );

      expect(payload['user_id'], '11111111-1111-1111-1111-111111111111');
    });

    test('trims label and details before they reach the insert', () {
      final payload = addressPayload(
        userId: 'uid',
        label: '  Home  ',
        details: '  Street 1  ',
      );

      expect(payload['label'], 'Home');
      expect(payload['details'], 'Street 1');
    });

    test('keeps coordinates null when the customer did not pick a point', () {
      final payload = addressPayload(
        userId: 'uid',
        label: 'Home',
        details: 'Street 1',
      );

      expect(payload['latitude'], isNull);
      expect(payload['longitude'], isNull);
    });

    test('passes coordinates through when present', () {
      final payload = addressPayload(
        userId: 'uid',
        label: 'Home',
        details: 'Street 1',
        latitude: 16.8892,
        longitude: 42.5511,
      );

      expect(payload['latitude'], 16.8892);
      expect(payload['longitude'], 42.5511);
    });

    test('defaults a new address to non-default', () {
      final payload = addressPayload(
        userId: 'uid',
        label: 'Home',
        details: 'Street 1',
      );

      expect(payload['is_default'], isFalse);
    });

    test('flags the address as default when requested', () {
      final payload = addressPayload(
        userId: 'uid',
        label: 'Home',
        details: 'Street 1',
        isDefault: true,
      );

      expect(payload['is_default'], isTrue);
    });
  });

  group('session guard', () {
    // No Supabase client exists in the local test environment, so every
    // operation that requires the signed-in session must fail before touching
    // the network. These prove the guard without a live backend.
    test('adding without a session fails before any insert', () async {
      SupabaseService.debugReset();
      addTearDown(SupabaseService.debugReset);
      expect(SupabaseService.isReady, isFalse);

      final repository = SupabaseAddressRepository();
      await expectLater(
        repository.addAddress(label: 'Home', details: 'Street 1'),
        throwsA(isA<StateError>()),
      );
    });

    test('listing without a session fails', () async {
      SupabaseService.debugReset();
      addTearDown(SupabaseService.debugReset);

      final repository = SupabaseAddressRepository();
      await expectLater(
        repository.listAddresses(),
        throwsA(isA<StateError>()),
      );
    });

    test('deleting without a session fails instead of returning quietly', () async {
      SupabaseService.debugReset();
      addTearDown(SupabaseService.debugReset);

      final repository = SupabaseAddressRepository();
      await expectLater(
        repository.removeAddress('some-address-id'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleting with an empty id is rejected', () async {
      SupabaseService.debugReset();
      addTearDown(SupabaseService.debugReset);

      final repository = SupabaseAddressRepository();
      await expectLater(
        repository.removeAddress(''),
        throwsArgumentError,
      );
    });
  });
}
