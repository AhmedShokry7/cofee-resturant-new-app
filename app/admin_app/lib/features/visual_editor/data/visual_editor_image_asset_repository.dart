import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/banners/di/banners_dependencies.dart';
import 'package:admin_app/features/bundles/di/bundles_dependencies.dart';
import 'package:admin_app/features/catalog/di/catalog_dependencies.dart';
import 'package:admin_app/features/subscription_plans_admin/di/subscription_plans_admin_dependencies.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';

/// A customer-facing image the visual editor can reference and, when the
/// current staff member has the owning feature permission, manage in place.
enum VisualEditorImageAssetKind { product, category, banner, bundle, plan }

class VisualEditorImageAsset {
  const VisualEditorImageAsset({
    required this.kind,
    required this.id,
    required this.imageUrl,
    required this.label,
    this.productImage,
  });

  final VisualEditorImageAssetKind kind;
  final String id;
  final String imageUrl;
  final String label;
  final AdminProductImage? productImage;
}

class VisualEditorImageAssetRepository {
  VisualEditorImageAssetRepository({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;
  CatalogData get _catalog => CatalogDependencies.catalog;

  Future<List<VisualEditorImageAsset>> loadAssets({
    bool includePlans = false,
  }) async {
    final client = _client;
    final results = await Future.wait<Object?>([
      client.rpc('admin_image_assets_catalog'),
      client.rpc('admin_image_assets_product_images'),
      client.rpc('admin_image_assets_banners'),
      client.rpc('admin_image_assets_bundles'),
      if (includePlans)
        SubscriptionPlansAdminDependencies.repository.loadPlans(),
    ]);

    final catalogRows = _maps(results[0]);
    final productRows = catalogRows
        .where((row) => row['asset_kind'] == 'product')
        .toList(growable: false);
    final categoryRows = catalogRows
        .where((row) => row['asset_kind'] == 'category')
        .toList(growable: false);
    final productNames = <String, String>{
      for (final row in productRows)
        '${row['id'] ?? ''}': _label(row['name_ar'], row['name_en']),
    };
    final assets = <VisualEditorImageAsset>[];
    final productImageUrls = <String>{};
    final productImageProductIds = <String>{};

    for (final row in _maps(results[1])) {
      final image = AdminProductImage.fromRow(row);
      if (!productNames.containsKey(image.productId)) continue;
      productImageProductIds.add(image.productId);
      if (image.imageUrl.trim().isEmpty) continue;
      productImageUrls.add('${image.productId}\u0000${image.imageUrl}');
      assets.add(
        VisualEditorImageAsset(
          kind: VisualEditorImageAssetKind.product,
          id: image.productId,
          imageUrl: image.imageUrl,
          label: productNames[image.productId] ?? image.productId,
          productImage: image,
        ),
      );
    }
    for (final row in productRows) {
      final url = _image(row['image_url']);
      final id = '${row['id'] ?? ''}';
      if (url.isEmpty ||
          productImageProductIds.contains(id) ||
          productImageUrls.contains('$id\u0000$url')) {
        continue;
      }
      assets.add(
        VisualEditorImageAsset(
          kind: VisualEditorImageAssetKind.product,
          id: id,
          imageUrl: url,
          label: _label(row['name_ar'], row['name_en']),
        ),
      );
    }

    _appendAssets(assets, categoryRows, VisualEditorImageAssetKind.category);
    _appendAssets(assets, _maps(results[2]), VisualEditorImageAssetKind.banner);
    _appendAssets(assets, _maps(results[3]), VisualEditorImageAssetKind.bundle);
    if (includePlans && results[4] is List<AdminSubscriptionPlan>) {
      final plans = results[4] as List<AdminSubscriptionPlan>;
      for (final plan in plans) {
        final url = _image(plan.imageUrl);
        if (url.isEmpty) continue;
        assets.add(
          VisualEditorImageAsset(
            kind: VisualEditorImageAssetKind.plan,
            id: plan.id,
            imageUrl: url,
            label: _label(plan.nameAr, plan.nameEn),
          ),
        );
      }
    }
    return assets;
  }

  void _appendAssets(
    List<VisualEditorImageAsset> assets,
    List<Map<String, dynamic>> rows,
    VisualEditorImageAssetKind kind,
  ) {
    for (final row in rows) {
      final url = _image(row['image_url']);
      if (url.isEmpty) continue;
      final label = switch (kind) {
        VisualEditorImageAssetKind.product => _label(
          row['name_ar'],
          row['name_en'],
        ),
        VisualEditorImageAssetKind.category => _label(
          row['name_ar'],
          row['name_en'],
        ),
        VisualEditorImageAssetKind.banner => _label(
          row['title_ar'],
          row['title_en'],
        ),
        VisualEditorImageAssetKind.bundle => _label(
          row['name_ar'],
          row['name_en'],
        ),
        VisualEditorImageAssetKind.plan => _label(
          row['name_ar'],
          row['name_en'],
        ),
      };
      assets.add(
        VisualEditorImageAsset(
          kind: kind,
          id: '${row['id'] ?? ''}',
          imageUrl: url,
          label: label,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  String _image(Object? value) => value is String ? value.trim() : '';

  String _label(Object? first, Object? second) {
    final a = _image(first);
    final b = _image(second);
    if (a.isEmpty) return b;
    if (b.isEmpty || a == b) return a;
    return '$a / $b';
  }

  Future<void> replaceImage(
    VisualEditorImageAsset asset,
    ProductImageSource source,
  ) async {
    switch (asset.kind) {
      case VisualEditorImageAssetKind.product:
        final images = await _catalog.loadProductImages(
          asset.id,
          fallbackImageUrl: asset.productImage == null ? asset.imageUrl : null,
        );
        final image = images.firstWhere(
          (entry) => entry.imageUrl == asset.imageUrl,
        );
        if (source.isLink) {
          await _catalog.updateProductImage(
            image: image,
            imageUrl: source.url!,
          );
        } else {
          await _catalog.replaceProductImageWithFile(
            image: image,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
      case VisualEditorImageAssetKind.category:
        if (source.isLink) {
          await _catalog.updateCategoryImage(asset.id, source.url);
          if (source.url != asset.imageUrl &&
              _isOwnedPath(asset.imageUrl, 'products/category-${asset.id}/')) {
            await _catalog.deleteCategoryImageFile(asset.imageUrl);
          }
        } else {
          // The catalogue repository stores the row and cleans its old file.
          await _catalog.uploadCategoryImage(
            categoryId: asset.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
      case VisualEditorImageAssetKind.banner:
        final repository = BannersDependencies.repository;
        if (source.isLink) {
          await repository.updateBannerImage(asset.id, source.url);
        } else {
          await repository.uploadBannerImage(
            bannerId: asset.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
        if (source.url != asset.imageUrl &&
            _isOwnedPath(asset.imageUrl, 'products/banners/${asset.id}/')) {
          await repository.deleteBannerImageFile(asset.imageUrl);
        }
      case VisualEditorImageAssetKind.bundle:
        final repository = BundlesDependencies.repository;
        if (source.isLink) {
          await repository.updateBundleImage(asset.id, source.url);
        } else {
          await repository.uploadBundleImage(
            bundleId: asset.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
        if (source.url != asset.imageUrl &&
            _isOwnedPath(asset.imageUrl, 'products/bundles/${asset.id}/')) {
          await repository.deleteBundleImageFile(asset.imageUrl);
        }
      case VisualEditorImageAssetKind.plan:
        final repository = SubscriptionPlansAdminDependencies.repository;
        if (source.isLink) {
          await repository.updatePlanImage(asset.id, source.url);
        } else {
          await repository.uploadPlanImage(
            planId: asset.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
        if (source.url != asset.imageUrl &&
            _isOwnedPath(
              asset.imageUrl,
              'products/subscription-plans/${asset.id}/',
            )) {
          await repository.deletePlanImageFile(asset.imageUrl);
        }
    }
  }

  bool _isOwnedPath(String imageUrl, String prefix) {
    final marker = '/product-images/';
    final index = imageUrl.indexOf(marker);
    if (index < 0) return false;
    return imageUrl.substring(index + marker.length).startsWith(prefix);
  }

  Future<void> removeImage(VisualEditorImageAsset asset) async {
    switch (asset.kind) {
      case VisualEditorImageAssetKind.product:
        final images = await _catalog.loadProductImages(
          asset.id,
          fallbackImageUrl: asset.productImage == null ? asset.imageUrl : null,
        );
        final image = images.firstWhere(
          (entry) => entry.imageUrl == asset.imageUrl,
        );
        await _catalog.deleteProductImage(image);
      case VisualEditorImageAssetKind.category:
        await _catalog.updateCategoryImage(asset.id, null);
        if (_isOwnedPath(asset.imageUrl, 'products/category-${asset.id}/')) {
          await _catalog.deleteCategoryImageFile(asset.imageUrl);
        }
      case VisualEditorImageAssetKind.banner:
        final repository = BannersDependencies.repository;
        await repository.updateBannerImage(asset.id, null);
        if (_isOwnedPath(asset.imageUrl, 'products/banners/${asset.id}/')) {
          await repository.deleteBannerImageFile(asset.imageUrl);
        }
      case VisualEditorImageAssetKind.bundle:
        final repository = BundlesDependencies.repository;
        await repository.updateBundleImage(asset.id, null);
        if (_isOwnedPath(asset.imageUrl, 'products/bundles/${asset.id}/')) {
          await repository.deleteBundleImageFile(asset.imageUrl);
        }
      case VisualEditorImageAssetKind.plan:
        final repository = SubscriptionPlansAdminDependencies.repository;
        await repository.updatePlanImage(asset.id, null);
        if (_isOwnedPath(
          asset.imageUrl,
          'products/subscription-plans/${asset.id}/',
        )) {
          await repository.deletePlanImageFile(asset.imageUrl);
        }
    }
  }
}
