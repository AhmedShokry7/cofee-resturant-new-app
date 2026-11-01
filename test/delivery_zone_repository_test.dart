import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/checkout/data/repositories/delivery_zone_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// When the `delivery_zones_for_branch` bridge is not deployed, the repository
/// classifies it as a typed [DeliveryZonesFailure] rather than returning an
/// empty list (which would read as "this branch serves no zones"). These tests
/// pin the PostgREST/Postgres error shapes that count as "bridge missing".
void main() {
  group('isMissingDeliveryZonesRpc', () {
    test('matches the PostgREST schema-cache miss (PGRST202)', () {
      final error = PostgrestException(
        message:
            'Could not find the function public.delivery_zones_for_branch('
            'p_branch_id) in the schema cache',
        code: 'PGRST202',
      );

      expect(isMissingDeliveryZonesRpc(error), isTrue);
    });

    test('matches Postgres undefined_function (42883)', () {
      final error = PostgrestException(
        message:
            'function public.delivery_zones_for_branch(uuid) does not exist',
        code: '42883',
      );

      expect(isMissingDeliveryZonesRpc(error), isTrue);
    });

    test('falls back to the message when no code is present', () {
      final error = PostgrestException(
        message:
            'Could not find the function public.delivery_zones_for_branch('
            'p_branch_id) in the schema cache',
      );

      expect(isMissingDeliveryZonesRpc(error), isTrue);
    });

    test('does not swallow unrelated PostgREST failures', () {
      final permission = PostgrestException(
        message: 'permission denied for function delivery_zones_for_branch',
        code: '42501',
      );
      final networkish = PostgrestException(
        message: 'JWT expired',
        code: 'PGRST301',
      );

      expect(isMissingDeliveryZonesRpc(permission), isFalse);
      expect(isMissingDeliveryZonesRpc(networkish), isFalse);
    });

    test('a missing bridge maps to the bridgeMissing failure category', () {
      final error = PostgrestException(
        message:
            'Could not find the function public.delivery_zones_for_branch('
            'p_branch_id) in the schema cache',
        code: 'PGRST202',
      );

      final wrapped = DeliveryZonesException(
        isMissingDeliveryZonesRpc(error)
            ? DeliveryZonesFailure.bridgeMissing
            : DeliveryZonesFailure.backendError,
        error,
      );

      expect(wrapped.failure, DeliveryZonesFailure.bridgeMissing);
      expect(wrapped.cause, same(error));
    });
  });
}
