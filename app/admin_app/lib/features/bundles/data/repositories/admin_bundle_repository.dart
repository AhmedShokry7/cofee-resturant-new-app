import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';

class AdminBundleException implements Exception {
  const AdminBundleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads and writes bundles of the admin dashboard.
class AdminBundleRepository {
  AdminBundleRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  /// Loads all bundles with their components.
  Future<List<AdminBundle>> loadBundles() async {
    final rows = await _supabase
        .from('bundles')
        .select(
          '*, bundle_items(*, products(id, name_ar, name_en, image_url, base_price, category_name_ar, category_name_en))',
        )
        .order('sort_order');

    return (rows as List)
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          final items = map['bundle_items'] as List<dynamic>?;
          final components =
              items?.map((item) {
                final m = Map<String, dynamic>.from(item as Map);
                final product = m['products'] as Map<String, dynamic>?;
                return AdminBundleComponent.fromJson({
                  'product_id': m['product_id'],
                  'quantity': m['quantity'],
                  'allow_options': m['allow_options'],
                  'name_ar': product?['name_ar'],
                  'name_en': product?['name_en'],
                  'category_name_ar': product?['category_name_ar'],
                  'category_name_en': product?['category_name_en'],
                  'image_url': product?['image_url'],
                  'base_price': product?['base_price'],
                });
              }).toList() ??
              const <AdminBundleComponent>[];
          map['components'] = components;
          return AdminBundle.fromJson(map);
        })
        .toList(growable: false);
  }

  /// Loads all products (for the component picker).
  Future<List<Map<String, dynamic>>> loadProducts() async {
    final rows = await _supabase
        .from('products')
        .select('id, name_ar, name_en, image_url, base_price')
        .isFilter('archived_at', null)
        .order('name_en');
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// Creates a bundle.
  Future<AdminBundle> createBundle(AdminBundle bundle) async {
    final response = await _supabase
        .from('bundles')
        .insert(bundle.toJson())
        .select()
        .single();

    final created = AdminBundle.fromJson(response);
    await _saveComponents(created.id, bundle.components);
    return created.copyWith(components: bundle.components);
  }

  /// Updates a bundle.
  Future<AdminBundle> updateBundle(AdminBundle bundle) async {
    await _supabase.from('bundles').update(bundle.toJson()).eq('id', bundle.id);

    // Replace components
    await _supabase.from('bundle_items').delete().eq('bundle_id', bundle.id);
    await _saveComponents(bundle.id, bundle.components);

    return bundle;
  }

  /// Deletes a bundle.
  Future<void> deleteBundle(String bundleId) async {
    try {
      await _supabase.rpc(
        'admin_delete_bundle',
        params: {'p_bundle_id': bundleId},
      );
    } on PostgrestException catch (error) {
      throw AdminBundleException(_deleteMessage(error));
    }
  }

  String _deleteMessage(PostgrestException error) {
    if (error.message.contains('bundle_in_use')) {
      return S.bundleDeleteBlockedByReward;
    }
    if (error.message.contains('bundle_not_found')) {
      return S.bundleNotFound;
    }
    return error.message;
  }

  /// Activates or deactivates a bundle.
  Future<void> setBundleActive(String bundleId, bool isActive) async {
    await _supabase
        .from('bundles')
        .update({'is_active': isActive})
        .eq('id', bundleId);
  }

  /// Points a bundle at another image url.
  Future<void> updateBundleImage(String bundleId, String? imageUrl) async {
    await _supabase
        .from('bundles')
        .update({'image_url': imageUrl})
        .eq('id', bundleId);
  }

  /// Uploads a picture of a bundle to the bucket and saves its url.
  Future<String> uploadBundleImage({
    String? bundleId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    void Function(AdminImageUploadPhase phase)? onPhase,
  }) async {
    if (bytes.isEmpty) throw Exception(S.imageIsEmpty);
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception(S.imageTooLarge);
    }

    final extension = _extensionOf(fileName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = 'products/bundles/${bundleId ?? 'new'}/$stamp$extension';

    onPhase?.call(AdminImageUploadPhase.uploading);
    await _supabase.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final url =
        '${AppConfig.supabaseUrl}/storage/v1/object/public/product-images/$path';

    onPhase?.call(AdminImageUploadPhase.saving);
    if (bundleId != null) {
      await updateBundleImage(bundleId, url);
    }
    return url;
  }

  /// Removes the file of a bundle image.
  Future<void> deleteBundleImageFile(String? imageUrl) async {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    final marker = '/product-images/';
    final idx = imageUrl.indexOf(marker);
    if (idx < 0) return;
    final path = imageUrl.substring(idx + marker.length);
    try {
      await _supabase.storage.from('product-images').remove([path]);
    } catch (_) {}
  }

  String _extensionOf(String fileName) {
    final name = fileName.toLowerCase();
    for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
      if (name.endsWith(ext)) return ext == '.jpeg' ? '.jpg' : ext;
    }
    return '.jpg';
  }

  Future<void> _saveComponents(
    String bundleId,
    List<AdminBundleComponent> components,
  ) async {
    if (components.isEmpty) return;
    final rows = components
        .map(
          (c) => <String, dynamic>{
            'bundle_id': bundleId,
            'product_id': c.productId,
            'quantity': c.quantity,
            'allow_options': c.allowOptions,
            'sort_order': components.indexOf(c),
          },
        )
        .toList();
    await _supabase.from('bundle_items').insert(rows);
  }
}
