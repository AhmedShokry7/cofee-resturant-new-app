import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';

class CustomerBundleRepository {
  CustomerBundleRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final c = _client;
    if (c == null) throw StateError('Supabase client unavailable');
    return c;
  }

  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) throw StateError('Not authenticated');
    return uid;
  }

  Future<List<CustomerBundle>> listMyBundles() async {
    final uid = _uid;
    final rows = await _db
        .from('customer_bundles')
        // PostgREST cannot parse a schema-qualified relation name in an
        // embedded select. Load the foreign-schema products in a second query.
        .select('*, items:customer_bundle_items(*)')
        .eq('user_id', uid)
        .order('is_favorite', ascending: false)
        .order('updated_at', ascending: false);
    return _mapBundles((rows as List).whereType<Map>());
  }

  Future<CustomerBundle?> getBundle(String id) async {
    final uid = _uid;
    final row = await _db
        .from('customer_bundles')
        .select('*, items:customer_bundle_items(*)')
        .eq('id', id)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return (await _mapBundles([Map<String, dynamic>.from(row)])).first;
  }

  Future<CustomerBundle> createBundle({
    required String name,
    String? description,
    bool isFavorite = false,
    List<CustomerBundleItem> items = const [],
  }) async {
    final uid = _uid;
    final inserted = await _db
        .from('customer_bundles')
        .insert({
          'user_id': uid,
          'name': name.trim(),
          'description': (description ?? '').trim().isEmpty
              ? null
              : description!.trim(),
          'is_favorite': isFavorite,
          'is_active': true,
        })
        .select()
        .single();
    final bundleId = inserted['id'].toString();
    if (items.isNotEmpty) {
      await _db
          .from('customer_bundle_items')
          .insert(
            items
                .map(
                  (i) => {
                    'bundle_id': bundleId,
                    'product_id': i.productId,
                    'quantity': i.quantity,
                    'selected_options': i.selectedOptions,
                    'note': i.note,
                  },
                )
                .toList(),
          );
    }
    return (await getBundle(bundleId))!;
  }

  Future<CustomerBundle> updateBundle({
    required String id,
    required String name,
    String? description,
    bool? isFavorite,
    bool? isActive,
    List<CustomerBundleItem>? items,
  }) async {
    final uid = _uid;
    final patch = <String, dynamic>{
      'name': name.trim(),
      'description': (description ?? '').trim().isEmpty
          ? null
          : description!.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (isFavorite != null) patch['is_favorite'] = isFavorite;
    if (isActive != null) patch['is_active'] = isActive;
    await _db
        .from('customer_bundles')
        .update(patch)
        .eq('id', id)
        .eq('user_id', uid);
    if (items != null) {
      await _db.from('customer_bundle_items').delete().eq('bundle_id', id);
      if (items.isNotEmpty) {
        await _db
            .from('customer_bundle_items')
            .insert(
              items
                  .map(
                    (i) => {
                      'bundle_id': id,
                      'product_id': i.productId,
                      'quantity': i.quantity,
                      'selected_options': i.selectedOptions,
                      'note': i.note,
                    },
                  )
                  .toList(),
            );
      }
    }
    return (await getBundle(id))!;
  }

  Future<void> deleteBundle(String id) async {
    final uid = _uid;
    await _db.from('customer_bundle_items').delete().eq('bundle_id', id);
    await _db.from('customer_bundles').delete().eq('id', id).eq('user_id', uid);
  }

  Future<CustomerBundle> duplicateBundle(String id) async {
    final src = await getBundle(id);
    if (src == null) throw StateError('Bundle not found');
    return createBundle(
      name: '${src.name} (copy)',
      description: src.description,
      isFavorite: false,
      items: src.items,
    );
  }

  Future<void> markUsed(String id) async {
    final uid = _uid;
    await _db
        .from('customer_bundles')
        .update({
          'last_used_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<List<CustomerBundle>> _mapBundles(Iterable<Map> rows) async {
    final bundles = rows.map((row) => Map<String, dynamic>.from(row)).toList();
    final productIds = bundles
        .expand(
          (bundle) =>
              bundle['items'] is List ? bundle['items'] as List : const [],
        )
        .whereType<Map>()
        .map((item) => item['product_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final productsById = <String, Map<String, dynamic>>{};
    if (productIds.isNotEmpty) {
      final products = await _db
          .from('products')
          .select('id,name_ar,name_en,image_url,base_price')
          .inFilter('id', productIds);
      for (final product in (products as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(product);
        productsById[row['id'].toString()] = row;
      }
    }
    return bundles.map((bundle) => _mapBundle(bundle, productsById)).toList();
  }

  CustomerBundle _mapBundle(
    Map<String, dynamic> json,
    Map<String, Map<String, dynamic>> productsById,
  ) {
    final rawItems = json['items'];
    final items = <CustomerBundleItem>[];
    if (rawItems is List) {
      for (final e in rawItems.whereType<Map>()) {
        final m = Map<String, dynamic>.from(e);
        final prod = productsById[m['product_id']?.toString()];
        if (prod != null) {
          final p = prod;
          m['product_name_ar'] = m['product_name_ar'] ?? p['name_ar'];
          m['product_name_en'] = m['product_name_en'] ?? p['name_en'];
          m['product_image_url'] = m['product_image_url'] ?? p['image_url'];
          m['unit_price'] = m['unit_price'] ?? p['base_price'];
        }
        items.add(CustomerBundleItem.fromJson(m));
      }
    }
    json['items'] = items
        .map(
          (i) => {
            'id': i.id,
            'bundle_id': i.bundleId,
            'product_id': i.productId,
            'quantity': i.quantity,
            'selected_options': i.selectedOptions,
            'note': i.note,
            'product_name_ar': i.productNameAr,
            'product_name_en': i.productNameEn,
            'product_image_url': i.productImageUrl,
            'unit_price': i.unitPrice,
          },
        )
        .toList();
    return CustomerBundle.fromJson(json);
  }
}
