import 'package:flutter/foundation.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/checkout/data/model/delivery_zone_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Why [DeliveryZoneRepository.zonesForBranch] could not return zones.
///
/// Absence of the `delivery_zones_for_branch` bridge is *not* evidence that the
/// branch serves no zones, so callers must not treat a failure as an empty
/// result.
enum DeliveryZonesFailure {
  /// PostgREST/Postgres reported the RPC itself as missing (`PGRST202`/
  /// `42883`): the bridge is not deployed or not exposed in this environment.
  bridgeMissing,

  /// Any other failure (network, permissions, malformed response, ...).
  backendError,
}

/// Raised when the checkout could not determine a branch's delivery zones. It
/// carries a non-sensitive [failure] category for logging and UI messaging; the
/// underlying [cause] is kept for the caller's diagnostics.
class DeliveryZonesException implements Exception {
  const DeliveryZonesException(this.failure, [this.cause]);

  final DeliveryZonesFailure failure;
  final Object? cause;

  @override
  String toString() => 'DeliveryZonesException(${failure.name})';
}

/// True when PostgREST reported [name] as absent, so callers can classify the
/// failure instead of mistaking it for "no zones".
///
/// PostgREST answers a missing function with `PGRST202` (schema-cache miss) and
/// Postgres uses `42883` (`undefined_function`); the message check covers
/// older/self-hosted gateways that omit the code.
@visibleForTesting
bool isMissingDeliveryZonesRpc(
  PostgrestException error, {
  String name = 'delivery_zones_for_branch',
}) {
  final code = error.code;
  if (code == 'PGRST202' || code == '42883') return true;
  return error.message.contains('Could not find the function') &&
      error.message.contains(name);
}

/// Delivery zones a branch delivers to.
///
/// The database is authoritative: the checkout must only offer zones the
/// branch actually serves, with the branch's own fee. There is deliberately no
/// seeded fallback, so a misconfigured backend shows "delivery unavailable"
/// rather than a fabricated fee.
abstract class DeliveryZoneRepository {
  Future<List<DeliveryZone>> zonesForBranch(String branchId);

  /// The zone that serves [latitude]/[longitude], nearest first.
  ///
  /// An empty list means the address is outside every zone this branch serves —
  /// the answer to "no delivery to your area". That is a real answer and is not
  /// an error; a thrown [DeliveryZonesException] means we could not tell, and
  /// the two must not be confused.
  ///
  /// The fee comes back priced for this address, so the number the customer
  /// sees is the one the server will charge.
  Future<List<DeliveryZone>> zonesForPoint({
    required String branchId,
    required double latitude,
    required double longitude,
  });
}

class SupabaseDeliveryZoneRepository implements DeliveryZoneRepository {
  SupabaseDeliveryZoneRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  @override
  Future<List<DeliveryZone>> zonesForBranch(String branchId) async {
    final client = _client;
    final branch = branchId.trim();
    if (client == null) {
      throw const DeliveryZonesException(DeliveryZonesFailure.backendError);
    }
    if (branch.isEmpty) return const [];

    final List<dynamic> rows;
    try {
      rows = await client.rpc(
        'delivery_zones_for_branch',
        params: <String, dynamic>{'p_branch_id': branch},
      ) as List;
    } on PostgrestException catch (error) {
      // A missing bridge is a backend/configuration problem, not "this branch
      // serves no zones". Surface it as a typed failure so the checkout can say
      // so instead of silently dropping delivery.
      throw DeliveryZonesException(
        isMissingDeliveryZonesRpc(error)
            ? DeliveryZonesFailure.bridgeMissing
            : DeliveryZonesFailure.backendError,
        error,
      );
    } catch (error) {
      throw DeliveryZonesException(DeliveryZonesFailure.backendError, error);
    }
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) DeliveryZone.fromDatabase(row),
    ];
  }

  @override
  Future<List<DeliveryZone>> zonesForPoint({
    required String branchId,
    required double latitude,
    required double longitude,
  }) async {
    final client = _client;
    final branch = branchId.trim();
    if (client == null) {
      throw const DeliveryZonesException(DeliveryZonesFailure.backendError);
    }
    if (branch.isEmpty) return const [];

    final List<dynamic> rows;
    try {
      rows = await client.rpc(
        'resolve_delivery_zone',
        params: <String, dynamic>{
          'p_branch_id': branch,
          'p_lat': latitude,
          'p_lng': longitude,
        },
      ) as List;
    } on PostgrestException catch (error) {
      throw DeliveryZonesException(
        isMissingDeliveryZonesRpc(error, name: 'resolve_delivery_zone')
            ? DeliveryZonesFailure.bridgeMissing
            : DeliveryZonesFailure.backendError,
        error,
      );
    } catch (error) {
      throw DeliveryZonesException(DeliveryZonesFailure.backendError, error);
    }
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) DeliveryZone.fromDatabase(row),
    ];
  }
}
