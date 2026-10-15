import 'dart:convert';

import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns favourite product ids on the device and in the database.
///
/// Device storage is the offline source of truth and the guest path: a signed
/// out customer still gets hearts. When Supabase is configured and a session
/// exists, the same ids are mirrored to `engagement.customer_favorites`, whose
/// RLS permits only the owning user. Local-only ids are uploaded after the
/// catalogue confirms they still identify real products, so a stale id can
/// never violate the `product_id` foreign key.
abstract class FavoritesRepository {
  Future<Set<String>> loadLocalIds();
  Future<Set<String>> synchronizedIds(
    Set<String> localIds, {
    required Set<String> validProductIds,
  });
  Future<void> addFavorite(String productId);
  Future<void> removeFavorite(String productId);
}

class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl({SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  static const _storageKey = 'favorites_v1';

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  User? get _user => _client?.auth.currentUser;

  @override
  Future<Set<String>> loadLocalIds() async {
    try {
      final raw = await SharedPref.getValue(key: _storageKey);
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
  Future<Set<String>> synchronizedIds(
    Set<String> localIds, {
    required Set<String> validProductIds,
  }) async {
    final user = _user;
    final client = _client;
    if (user == null || client == null) return localIds;

    final remoteIds = await _remoteIds(client, user.id);
    final uploadable = localIds
        .where(validProductIds.contains)
        .where((id) => !remoteIds.contains(id))
        .toList(growable: false);
    for (final id in uploadable) {
      try {
        await client.from('customer_favorites').insert({
          'user_id': user.id,
          'product_id': id,
        });
      } on PostgrestException catch (error) {
        // A product deleted between the catalogue read and this insert must
        // not fail the whole sync. Anything else is a real backend problem.
        if (error.code != '23503') rethrow;
      }
    }
    return {...localIds, ...remoteIds};
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
    final rows = await client
        .from('customer_favorites')
        .select('product_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1000) as List;
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
      await SharedPref.setValue(
        key: _storageKey,
        value: jsonEncode(ids.toList()),
      );
    } catch (_) {
      // Best-effort: never break toggling if storage fails.
    }
  }
}
