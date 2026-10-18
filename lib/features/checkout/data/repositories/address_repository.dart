import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer-owned delivery addresses.
///
/// Addresses live in `identity.customer_addresses` with owner-only RLS. There
/// is deliberately no server table for saved cards, so those stay on the
/// device: a card number is not an address, and no order references one.
abstract class AddressRepository {
  Future<List<AddressModel>> listAddresses();
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  });
  Future<AddressModel> updateAddress({
    required String id,
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  });
  Future<void> setDefaultAddress(String id);
  Future<void> removeAddress(String id);
}

/// Insert payload for a new customer address.
///
/// `user_id` is mandatory: the column has no default (migration 003) and the
/// owner-only RLS policy (migration 019) enforces `user_id = auth.uid()`, so an
/// insert that omits it is always rejected — the address could never be saved.
Map<String, Object?> addressPayload({
  required String userId,
  required String label,
  required String details,
  double? latitude,
  double? longitude,
  bool isDefault = false,
}) => {
  'user_id': userId,
  'label': label.trim(),
  'details': details.trim(),
  'latitude': ?latitude,
  'longitude': ?longitude,
  'is_default': isDefault,
};

class SupabaseAddressRepository implements AddressRepository {
  SupabaseAddressRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Addresses need a signed-in account.');
    }
    return client;
  }

  @override
  Future<List<AddressModel>> listAddresses() async {
    final client = _requireClient();

    final rows =
        await client
                .from('customer_addresses')
                .select()
                .isFilter('archived_at', null)
                .order('is_default', ascending: false)
                .order('created_at')
            as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) AddressModel.fromDatabase(row),
    ];
  }

  @override
  Future<AddressModel> addAddress({
    required String label,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final client = _requireClient();
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Addresses need a signed-in account.');
    }
    final rows =
        await client.from('customer_addresses').insert(
              addressPayload(
                userId: userId,
                label: label,
                details: details,
                latitude: latitude,
                longitude: longitude,
                isDefault: isDefault,
              ),
            ).select()
            as List;
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw StateError('Could not save the address.');
    }
    return AddressModel.fromDatabase(rows.first as Map<String, dynamic>);
  }

  @override
  Future<AddressModel> updateAddress({
    required String id,
    required String label,
    required String details,
    double? latitude,
    double? longitude,
  }) async {
    final client = _requireClient();
    final rows =
        await client
            .from('customer_addresses')
            .update({
              'label': label.trim(),
              'details': details.trim(),
              'latitude': ?latitude,
              'longitude': ?longitude,
            })
            .eq('id', id)
            .select()
            as List;
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw StateError('Could not update the address.');
    }
    return AddressModel.fromDatabase(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    final client = _requireClient();
    await client.rpc('set_default_address', params: {'p_address_id': id});
  }

  @override
  Future<void> removeAddress(String id) async {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Address id is required.');
    }
    final client = _requireClient();
    // Soft delete: an address may still appear on an older order snapshot.
    // `.select()` returns the rows the caller may actually see: when the
    // owner-only RLS hides the row from this session, the update matches
    // nothing and the empty result is reported as a failure instead of a
    // silent success that would drop the address from the local list while
    // leaving it readable on the server.
    final rows = await client
        .from('customer_addresses')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        as List;
    if (rows.isEmpty) {
      throw StateError('Could not delete the address.');
    }
  }
}
