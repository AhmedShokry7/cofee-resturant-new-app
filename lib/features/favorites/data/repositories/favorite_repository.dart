import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns favourite product ids on the device and in the database.
///
/// Device storage is namespaced per account ([storageKeyFor]): two customers
/// sharing one device never see each other's hearts. A guest list is adopted
/// into the account once, on the first load after sign-in (see
/// [migrateGuestIds]), instead of leaking across accounts.
///
/// When Supabase is configured and a session exists, the same ids are mirrored
/// to `engagement.customer_favorites`, whose RLS permits only the owning
/// user. Local-only ids are uploaded after the catalogue confirms they still
/// identify real products, so a stale id can never violate the `product_id`
/// foreign key.
abstract class FavoritesRepository {
  Future<Set<String>> loadLocalIds();

  /// The hearts the signed-in customer already has on the server.
  ///
  /// Empty when Supabase is not configured or nobody is signed in, so the
  /// caller can build the list it shows without branching on the session.
  Future<Set<String>> loadRemoteIds();

  /// Uploads the device hearts the server does not have yet.
  ///
  /// [validProductIds] are the ids the catalogue confirms still identify real
  /// products: anything else would violate the `product_id` foreign key. A
  /// guest has no server list, so this writes nothing.
  Future<void> synchronize({
    required Set<String> localIds,
    required Set<String> remoteIds,
    required Set<String> validProductIds,
  });

  Future<void> addFavorite(String productId);
  Future<void> removeFavorite(String productId);

  /// Moves the signed-out guest list into the signed-in account once, then
  /// clears the guest slot. No-op when signed out or when there is nothing
  /// to move.
  Future<void> migrateGuestIds();
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl({SupabaseClient? client, this._userIdProvider})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  final String? Function()? _userIdProvider;

  /// Device key for one account's hearts. `null` is the signed-out guest list.
  /// Never share a key across accounts: that leaks one customer's hearts
  /// into another's.
  static String storageKeyFor(String? userId) =>
      'favorites_v1_${userId ?? 'guest'}';

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  User? get _user => _client?.auth.currentUser;

  String? get _effectiveUserId => _userIdProvider?.call() ?? _user?.id;

  String get _key => storageKeyFor(_effectiveUserId);

  @override
  Future<Set<String>> loadLocalIds() async {
    try {
      final raw = await SharedPref.getValue(key: _key);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const {};
      return {for (final item in decoded) item.toString()};
    } catch (_) {
      // Favourites are best-effort: start empty rather than crash.
      return const {};
    }
  }

  @override
  Future<void> migrateGuestIds() async {
    if (_effectiveUserId == null) return;
    final guestKey = storageKeyFor(null);
    if (guestKey == _key) return;

    final guestRaw = await SharedPref.getValue(key: guestKey);
    if (guestRaw == null || guestRaw.isEmpty) return;
    final guestDecoded = jsonDecode(guestRaw);
    if (guestDecoded is! List || guestDecoded.isEmpty) {
      await SharedPref.setValue(key: guestKey, value: jsonEncode([]));
      return;
    }
    final guestIds = {for (final item in guestDecoded) item.toString()};

    // Read the account slot directly so a read failure is not mistaken for an
    // empty account; migration must abort rather than overwrite favorites.
    final accountRaw = await SharedPref.getValue(key: _key);
    final Set<String> accountIds;
    if (accountRaw == null || accountRaw.isEmpty) {
      accountIds = <String>{};
    } else {
      final accountDecoded = jsonDecode(accountRaw);
      if (accountDecoded is! List) {
        throw const FormatException('Invalid account favorites');
      }
      accountIds = {for (final item in accountDecoded) item.toString()};
    }

    final owned = {...accountIds, ...guestIds};
    // Write the merged account list before clearing guest data. A write failure
    // leaves the guest slot intact for retry.
    await SharedPref.setValue(key: _key, value: jsonEncode(owned.toList()));
    await SharedPref.setValue(key: guestKey, value: jsonEncode([]));
  }

  @override
  Future<Set<String>> loadRemoteIds() async {
    final user = _user;
    final client = _client;
    if (user == null || client == null) return const {};
    return _remoteIds(client, user.id);
  }

  @override
  Future<void> synchronize({
    required Set<String> localIds,
    required Set<String> remoteIds,
    required Set<String> validProductIds,
  }) async {
    final user = _user;
    final client = _client;
    if (user == null || client == null) return;

    final uploadable = localIds
        .where(validProductIds.contains)
        .where((id) => !remoteIds.contains(id))
        .toList(growable: false);
    if (uploadable.isEmpty) return;
    try {
      // One RPC inserts the missing ids with ON CONFLICT DO NOTHING. Syncing
      // 100 local hearts therefore costs one write request, not 100.
      await client.rpc(
        'sync_customer_favorites',
        params: {'p_product_ids': uploadable},
      );
    } on PostgrestException catch (error) {
      if (error.code != '23503' && error.code != 'PGRST202') rethrow;
      // Keep compatibility with older deployments and tolerate a product
      // deleted between catalogue loading and sync.
      for (final id in uploadable) {
        try {
          await client.from('customer_favorites').insert({
            'user_id': user.id,
            'product_id': id,
          });
        } on PostgrestException catch (insertError) {
          if (insertError.code != '23503' && insertError.code != '23505') {
            rethrow;
          }
        }
      }
    }
  }

  @override
  Future<void> addFavorite(String productId) async {
    final ids = {...await loadLocalIds()}..add(productId);
    await _persistLocal(ids);
    await _insertRemote(productId);
  }

  @override
  Future<void> removeFavorite(String productId) async {
    final ids = {...await loadLocalIds()}..remove(productId);
    await _persistLocal(ids);

    final user = _user;
    final client = _client;
    if (user == null || client == null) return;
    await client
        .from('customer_favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', productId);
  }

  Future<Set<String>> _remoteIds(SupabaseClient client, String userId) async {
    final rows =
        await client
                .from('customer_favorites')
                .select('product_id')
                .eq('user_id', userId)
                .order('created_at', ascending: false)
                .limit(1000)
            as List;
    return {
      for (final row in rows)
        if (row is Map && (row['product_id']?.toString() ?? '').isNotEmpty)
          row['product_id'].toString(),
    };
  }

  Future<void> _insertRemote(String productId) async {
    final user = _user;
    final client = _client;
    if (user == null || client == null) return;
    try {
      await client.from('customer_favorites').insert({
        'user_id': user.id,
        'product_id': productId,
      });
    } on PostgrestException catch (error) {
      // A repeated tap can race a previous insert. The unique key makes the
      // second write fail safely, and the heart is already stored locally.
      if (error.code != '23505') rethrow;
    }
  }

  Future<void> _persistLocal(Set<String> ids) async {
    try {
      await SharedPref.setValue(key: _key, value: jsonEncode(ids.toList()));
    } catch (_) {
      // Best-effort: never break toggling if storage fails.
    }
  }
}
