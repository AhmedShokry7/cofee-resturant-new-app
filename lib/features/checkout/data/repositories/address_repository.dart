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
  });
  Future<void> removeAddress(String id);
}

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
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Addresses need a signed-in account.');
    }
    final rows =
        await client.from('customer_addresses').insert({
              'label': label.trim(),
              'details': details.trim(),
              'latitude': ?latitude,
              'longitude': ?longitude,
            }).select()
            as List;
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw StateError('Could not save the address.');
    }
    return AddressModel.fromDatabase(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> removeAddress(String id) async {
    final client = _client;
    if (client == null || id.isEmpty) return;
    // Soft delete: an address may still appear on an older order snapshot.
    await client
        .from('customer_addresses')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
