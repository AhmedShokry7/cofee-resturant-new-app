import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_read_service.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the catalogue from Supabase.
///
/// Talks to the `public` routing views created in 032 and to the RPCs in 035.
/// Those views are declared WITH (security_invoker = true), so every query here
/// runs under the caller's own role and the catalogue RLS policies decide the
/// rows. Nothing here needs a privileged key, and the service_role key is never
/// referenced.
class SupabaseProductRepository implements CatalogRepository {
  SupabaseProductRepository([SupabaseClient? client])
    : _client = client ?? SupabaseReadService.read;

  final SupabaseClient _client;

  // Explicit column lists instead of select('*'): the client asks for exactly
  // what its models read, so a future column on the table can never leak into
  // the app or break a parser by surprise.
  static const _productColumns =
      'id, category_id, sku, slug, name_ar, name_en, description_ar, '
      'description_en, base_price, compare_at_price, image_url, is_featured, '
      'prep_minutes, category_slug, category_name_ar, category_name_en, '
      'related_product_ids';

  static const _productImageColumns =
      'id, product_id, image_url, alt_ar, alt_en, is_primary, sort_order';

  static const _optionGroupColumns =
      'id, code, name_ar, name_en, selection_type, min_select, max_select, '
      'is_required, sort_order, is_active';

  static const _optionValueColumns =
      'id, group_id, code, name_ar, name_en, price_delta, short_label, '
      'is_default, sort_order, is_active';

  static const _bundleColumns =
      'id, name_ar, name_en, description_ar, description_en, image_url, '
      'bundle_price, is_active, sort_order';

  static const _bundleItemColumns =
      'id, bundle_id, product_id, quantity, allow_options, sort_order, '
      'product:products(id, name_ar, name_en, image_url)';

  static const _categoryColumns =
      'id, slug, parent_id, name_ar, name_en, description_ar, description_en, '
      'image_url, icon_key, sort_order, is_active';

  /// Branch pricing is fetched separately and merged in Dart.
  ///
  /// PostgREST cannot infer the relationship on a view, so embedding would
  /// silently return nothing. Two explicit queries are clearer and cheaper than
  /// a join the cache cannot see.
  Future<Map<String, _BranchPrice>> _branchPrices(
    List<String> productIds,
    String? branchId,
  ) async {
    if (branchId == null || productIds.isEmpty) return {};
    final rows = await _client
        .from('branch_product_pricing')
        .select('product_id, price_override, is_available, unavailable_reason')
        .eq('branch_id', branchId)
        .inFilter('product_id', productIds);

    return {
      for (final r in rows)
        r['product_id']?.toString() ?? '': _BranchPrice(
          priceOverride: Db.asDoubleOrNull(r['price_override']),
          isAvailable: r['is_available'] == true,
          reason: Db.textOrNull(r['unavailable_reason']),
        ),
    };
  }

  ProductModel _withBranch(
    ProductModel product,
    Map<String, _BranchPrice> prices,
  ) {
    final override = prices[product.id];
    if (override == null) return product;
    return product.copyWith(price: override.priceOverride ?? product.price);
  }

  ProductModel _fromRpcRow(Map<String, dynamic> row) => ProductModel(
    id: Db.text(row['id']),
    name:
        Db.textOrNull(row['name']) ??
        Db.textOrNull(row['name_en']) ??
        Db.textOrNull(row['name_ar']) ??
        '',
    nameAr: Db.textOrNull(row['name_ar']),
    nameEn: Db.textOrNull(row['name_en']),
    description:
        Db.textOrNull(row['description']) ??
        Db.textOrNull(row['description_en']) ??
        Db.textOrNull(row['description_ar']) ??
        '',
    descriptionAr: Db.textOrNull(row['description_ar']),
    descriptionEn: Db.textOrNull(row['description_en']),
    category: Db.textOrNull(row['category_name']) ?? '',
    categoryAr: Db.textOrNull(row['category_name_ar']),
    categoryEn: Db.textOrNull(row['category_name_en']),
    categoryId: Db.textOrNull(row['category_id']),
    categorySlug: Db.textOrNull(row['category_slug']) ?? '',
    slug: Db.textOrNull(row['slug']),
    price: Db.asDouble(row['effective_price'] ?? row['base_price']),
    image: Db.textOrNull(row['image_url']) ?? '',
    isFeatured: row['rank'] != null,
  );

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    final rows = await (categoryId == null
        ? _client
              .from('products')
              .select(_productColumns)
              .range(offset, offset + limit - 1)
              .order('sort_order', ascending: true)
        : _client
              .from('products')
              .select(_productColumns)
              .eq('category_id', categoryId)
              .range(offset, offset + limit - 1)
              .order('sort_order', ascending: true));
    if (rows.isEmpty) return [];

    final productIds = rows.map((r) => r['id'].toString()).toList();

    // The images and the branch prices are independent of each other: both
    // only need the product ids the query above just returned, and neither
    // reads the other's result. They are therefore requested together, so a
    // catalogue read costs two round trips instead of three.
    //
    // Batch-fetch all product images in a single query to avoid N+1.
    final imageRowsFuture = _client
        .from('product_images')
        .select(_productImageColumns)
        .inFilter('product_id', productIds)
        .order('sort_order', ascending: true);

    // _branchPrices still issues no request when there is no branch, so a
    // catalogue read without a selected branch stays at a single follow-up.
    final pricesFuture = _branchPrices(productIds, branchId);

    // eagerError keeps the previous error semantics: the first failure is
    // reported straight away, and the sibling's rejection is absorbed here
    // instead of surfacing as an unhandled asynchronous error.
    final results = await Future.wait<Object>(
      <Future<Object>>[imageRowsFuture, pricesFuture],
      eagerError: true,
    );
    final imageRows = results[0] as List<Map<String, dynamic>>;
    final prices = results[1] as Map<String, _BranchPrice>;

    // Map image records to product IDs as ProductImage objects.
    final imageMap = <String, List<ProductImage>>{};
    for (final row in imageRows) {
      final pid = row['product_id'].toString();
      imageMap
          .putIfAbsent(pid, () => [])
          .add(ProductImage.fromJson(Map<String, dynamic>.from(row)));
    }

    return rows
        .map((r) {
          final product = ProductModel.fromJson(r);
          final images = imageMap[r['id'].toString()] ?? [];
          final imageUrls = images.map((img) => img.url).toList();
          final primaryImageUrl =
              _determinePrimaryImageUrl(images) ??
              (product.image.trim().isEmpty ? null : product.image.trim());
          return product.copyWith(
            imageUrls: imageUrls.isNotEmpty ? imageUrls : const [],
            primaryImageUrl: primaryImageUrl,
            isPrimaryImageAvailable: primaryImageUrl != null,
          );
        })
        .toList()
        .map((product) => _withBranch(product, prices))
        .toList();
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    final rows = await _client
        .from('products')
        .select(_productColumns)
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    final product = ProductModel.fromJson(rows.first);
    final prices = await _branchPrices([product.id], branchId);
    return _withBranch(product, prices);
  }

  @override
  Future<ProductWithOptions?> getWithOptions(
    String id, {
    String? branchId,
  }) async {
    // The product row and its option bindings do not depend on each other, so
    // they are fetched together rather than one round trip after another.
    final productFuture = getById(id, branchId: branchId);
    final linksFuture = _client
        .from('product_option_groups')
        .select('group_id, sort_order, is_required')
        .eq('product_id', id);

    final product = await productFuture;
    final links = await linksFuture;
    if (product == null) return null;

    final bindingByGroup = {
      for (final link in links) link['group_id'].toString(): link,
    };
    final groupIds = bindingByGroup.keys.toList();
    if (groupIds.isEmpty) {
      return ProductWithOptions(
        product: product,
        images: await _productImages(id),
      );
    }

    final groupRows = await _client
        .from('option_groups')
        .select(_optionGroupColumns)
        .eq('is_active', true)
        .inFilter('id', groupIds);
    final valueRows = await _client
        .from('option_values')
        .select(_optionValueColumns)
        .eq('is_active', true)
        .inFilter('group_id', groupIds);

    final valuesByGroup = <String, List<OptionValue>>{};
    for (final v in valueRows) {
      final gid = v['group_id'].toString();
      valuesByGroup.putIfAbsent(gid, () => []).add(OptionValue.fromJson(v));
    }
    for (final list in valuesByGroup.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final groups = <OptionGroup>[];
    for (final g in groupRows) {
      final parsed = OptionGroup.fromJson(g);
      final values = valuesByGroup[g['id'].toString()] ?? const <OptionValue>[];
      if (values.isEmpty) continue;
      final binding = bindingByGroup[parsed.id];
      groups.add(
        effectiveProductOptionGroup(
          group: parsed,
          bindingIsRequired: binding?['is_required'] == true,
          bindingSortOrder: (binding?['sort_order'] as num?)?.toInt() ?? 0,
          values: values,
        ),
      );
    }
    groups.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ProductWithOptions(
      product: product,
      groups: groups,
      images: await _productImages(id),
    );
  }

  /// Option groups for many products, in three parallel queries instead of
  /// six per product.
  ///
  /// The assistant reads this for the whole menu at once when it opens. The
  /// groups themselves (size, sugar, extras) are a small shared catalogue, so
  /// one pass over the bindings is enough to rebuild every product's list.
  ///
  /// The three reads do not depend on each other, so they run together: the
  /// bindings only need the product ids when the caller has them, and the
  /// groups and values are global.
  @override
  Future<Map<String, List<OptionGroup>>> getOptionsByProduct(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) {
      final all = await _optionsFor(const []);
      return all;
    }
    return _optionsFor(productIds);
  }

  /// The three option reads, side by side.
  Future<Map<String, List<OptionGroup>>> _optionsFor(
    List<String> productIds,
  ) async {
    final linksFuture = _client
        .from('product_option_groups')
        .select('product_id, group_id, sort_order, is_required')
        .limit(2000);
    final groupsFuture = _client
        .from('option_groups')
        .select(_optionGroupColumns)
        .eq('is_active', true);
    final valuesFuture = _client
        .from('option_values')
        .select(_optionValueColumns)
        .eq('is_active', true);

    final links = await linksFuture;
    final groupRows = await groupsFuture;
    final valueRows = await valuesFuture;

    final wanted = productIds.isEmpty ? null : productIds.toSet();
    final groupsById = <String, OptionGroup>{};
    for (final g in groupRows) {
      final parsed = OptionGroup.fromJson(g);
      groupsById[parsed.id] = OptionGroup(
        id: parsed.id,
        code: parsed.code,
        nameAr: parsed.nameAr,
        nameEn: parsed.nameEn,
        isSingleSelect: parsed.isSingleSelect,
        minSelect: parsed.minSelect,
        maxSelect: parsed.maxSelect,
        isRequired: parsed.isRequired,
        sortOrder: parsed.sortOrder,
        values: const [],
      );
    }
    final valuesByGroup = <String, List<OptionValue>>{};
    for (final v in valueRows) {
      final gid = v['group_id'].toString();
      valuesByGroup.putIfAbsent(gid, () => []).add(OptionValue.fromJson(v));
    }
    for (final list in valuesByGroup.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final byProduct = <String, List<OptionGroup>>{};
    for (final link in links) {
      final productId = link['product_id'].toString();
      if (wanted != null && !wanted.contains(productId)) continue;
      final group = groupsById[link['group_id'].toString()];
      if (group == null) continue;
      final values = valuesByGroup[group.id] ?? const [];
      byProduct.putIfAbsent(productId, () => []).add(
        effectiveProductOptionGroup(
          group: group,
          bindingIsRequired: link['is_required'] == true,
          bindingSortOrder: (link['sort_order'] as num?)?.toInt() ?? 0,
          values: values,
        ),
      );
    }
    for (final list in byProduct.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return byProduct;
  }

  Future<List<ProductImage>> _productImages(String productId) async {
    final rows = await _client
        .from('product_images')
        .select(_productImageColumns)
        .eq('product_id', productId)
        .order('sort_order', ascending: true);
    return rows.map(ProductImage.fromJson).toList();
  }

  /// Determines the primary image URL from a list of [ProductImage] records.
  /// Priority: explicit is_primary flag, then lowest sort_order, then fall back
  /// to the product-level [image] field, and finally null.
  static String? _determinePrimaryImageUrl(List<ProductImage> images) {
    // 1. Image explicitly marked as primary.
    final primary = images.firstWhere(
      (img) => img.isPrimary,
      orElse: () => ProductImage(url: '', isPrimary: false),
    );
    if (primary.isPrimary && primary.url.isNotEmpty) {
      return primary.url;
    }

    // 2. Otherwise, the image with the lowest sort_order.
    final sorted = images..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (sorted.isNotEmpty && sorted.first.url.isNotEmpty) {
      return sorted.first.url;
    }

    // 3. Fall back to the product-level image_url.
    return null;
  }

  /// Parses a `timestamptz` value from PostgREST into UTC. Null when absent
  /// or unparseable, which the publish-window check treats as "no bound".
  static DateTime? _asUtcDate(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed : parsed.toUtc();
  }

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'search_products',
      params: {
        if (query.trim().isNotEmpty) 'p_query': query.trim(),
        // Optional parameters may be omitted; p_branch_id is optional here so
        // omitting it is correct and lets the server fall back to base prices.
        'p_branch_id': ?branchId,
        'p_category_id': ?categoryId,
        'p_sort': sort,
        'p_page': (offset ~/ limit) + 1,
        'p_page_size': limit,
      },
    );
    return (rows as List)
        .map((r) => _fromRpcRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) async {
    final rows = await _client.rpc(
      'get_featured',
      params: {
        // p_branch_id has no default on the server, so it must always be sent.
        // Passing null explicitly is different from omitting the key: omission
        // makes PostgREST fail to match the signature (PGRST202).
        'p_branch_id': branchId,
        'p_limit': limit,
      },
    );
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return FeaturedProduct(
        productId: Db.text(m['product_id']),
        nameAr: Db.text(m['name_ar']),
        nameEn: Db.text(m['name_en']),
        imageUrl: Db.textOrNull(m['image_url']),
        effectivePrice: Db.asDouble(m['effective_price']),
        source: Db.text(m['source'], 'manual'),
        categoryAr: Db.textOrNull(m['category_name_ar']),
        categoryEn: Db.textOrNull(m['category_name_en']),
      );
    }).toList();
  }

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) async {
    final rows = await _client.rpc(
      'get_best_sellers',
      params: {
        'p_branch_id': branchId,
        'p_period': '${period.inDays} days',
        'p_limit': limit,
      },
    );
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return BestSeller(
        productId: Db.text(m['product_id']),
        nameAr: Db.text(m['name_ar']),
        nameEn: Db.text(m['name_en']),
        imageUrl: Db.textOrNull(m['image_url']),
        unitsSold: Db.asInt(m['units_sold']),
        revenue: Db.asDouble(m['revenue']),
      );
    }).toList();
  }

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) async {
    final rows = await _client.rpc(
      'resolve_effective_price',
      params: {
        'p_branch_id': branchId,
        'p_product_id': productId,
        'p_option_value_ids': optionValueIds,
      },
    );
    if (rows.isEmpty) return null;
    final m = rows.first as Map<String, dynamic>;
    return ResolvedPrice(
      unitPrice: Db.asDouble(m['unit_price']),
      currencyCode: Db.text(m['currency_code'], 'SAR'),
      isAvailable: m['is_available'] == true,
      unavailableReason: Db.textOrNull(m['unavailable_reason']),
    );
  }

  // --- Home page content ---------------------------------------------------

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) async {
    // Only eq/order/limit filters here: complex `or` date expressions are a
    // PostgREST version-sensitive failure point, and a 400 on this query
    // would empty the whole banner section. The publish window is enforced
    // below in Dart instead, with identical semantics.
    final fetched = await _client
        .from('banners')
        .select(
          'id,title_ar,title_en,subtitle_ar,subtitle_en,description_ar,'
          'description_en,image_url,cta_label_ar,cta_label_en,target_type,'
          'target_id,target_url,sort_order,is_published,starts_at,ends_at',
        )
        .eq('is_published', true)
        .order('sort_order')
        .limit(limit);

    final now = DateTime.now().toUtc();
    final rows = fetched.where((r) {
      final start = _asUtcDate(r['starts_at']);
      if (start != null && now.isBefore(start)) return false;
      final end = _asUtcDate(r['ends_at']);
      if (end != null && now.isAfter(end)) return false;
      return true;
    }).toList();

    return rows.map((r) => BannerModel.fromJson(r)).toList();
  }

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = 20,
  }) async {
    final rows = await _client
        .from('bundles')
        .select(_bundleColumns)
        .eq('is_active', true)
        .order('sort_order')
        .limit(limit);
    if (rows.isEmpty) return [];

    final bundleIds = rows.map((r) => r['id'].toString()).toList();
    final items = await _client
        .from('bundle_items')
        .select(_bundleItemColumns)
        .inFilter('bundle_id', bundleIds)
        .order('sort_order');

    final byBundle = <String, List<BundleComponent>>{};
    for (final row in items) {
      final bundleId = row['bundle_id'].toString();
      final product = row['product'];
      final embedded = product is Map ? product : const <String, dynamic>{};
      byBundle
          .putIfAbsent(bundleId, () => [])
          .add(
            BundleComponent(
              productId: Db.text(row['product_id']),
              quantity: Db.asInt(row['quantity'], fallback: 1),
              allowOptions: row['allow_options'] == true,
              nameAr: Db.textOrNull(embedded['name_ar']),
              nameEn: Db.textOrNull(embedded['name_en']),
              imageUrl: Db.textOrNull(embedded['image_url']),
            ),
          );
    }

    return rows
        .map(
          (r) => BundleModel.fromJson(
            r,
            components: byBundle[r['id'].toString()] ?? const [],
          ),
        )
        .toList();
  }

  @override
  Future<BundleModel?> getBundleById(String id) async {
    final rows = await _client
        .from('bundles')
        .select(_bundleColumns)
        .eq('id', id)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) return null;
    final bundle = rows.first;
    final bundleId = bundle['id'].toString();
    final items = await _client
        .from('bundle_items')
        .select(_bundleItemColumns)
        .eq('bundle_id', bundleId)
        .order('sort_order');

    final byBundle = <String, List<BundleComponent>>{};
    for (final row in items) {
      final product = row['product'];
      final embedded = product is Map ? product : const <String, dynamic>{};
      byBundle
          .putIfAbsent(bundleId, () => [])
          .add(
            BundleComponent(
              productId: Db.text(row['product_id']),
              quantity: Db.asInt(row['quantity'], fallback: 1),
              allowOptions: row['allow_options'] == true,
              nameAr: Db.textOrNull(embedded['name_ar']),
              nameEn: Db.textOrNull(embedded['name_en']),
              imageUrl: Db.textOrNull(embedded['image_url']),
            ),
          );
    }

    return BundleModel.fromJson(
      bundle,
      components: byBundle[bundleId] ?? const [],
    );
  }

  // --- CategoryRepository --------------------------------------------------

  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async {
    // Built in one expression: the PostgREST builder changes type after each
    // filter, so reassigning a `var` across filters does not type check.
    final rows = await (includeInactive
        ? _client
              .from('categories')
              .select(_categoryColumns)
              .order('sort_order')
        : _client
              .from('categories')
              .select(_categoryColumns)
              .eq('is_active', true)
              .order('sort_order'));
    return rows.map(CategoryModel.fromJson).toList();
  }

  @override
  Future<CategoryModel?> getCategoryById(String id) async {
    final rows = await _client
        .from('categories')
        .select(_categoryColumns)
        .eq('id', id)
        .limit(1);
    return rows.isEmpty ? null : CategoryModel.fromJson(rows.first);
  }

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) async {
    final rows = await _client
        .from('categories')
        .select(_categoryColumns)
        .eq('slug', slug)
        .limit(1);
    return rows.isEmpty ? null : CategoryModel.fromJson(rows.first);
  }

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) async {
    final rows = await _client
        .from('categories')
        .select(_categoryColumns)
        .eq('parent_id', parentId)
        .order('sort_order');
    return rows.map(CategoryModel.fromJson).toList();
  }
}

class _BranchPrice {
  const _BranchPrice({
    required this.isAvailable,
    this.priceOverride,
    this.reason,
  });

  final double? priceOverride;
  final bool isAvailable;
  final String? reason;
}
