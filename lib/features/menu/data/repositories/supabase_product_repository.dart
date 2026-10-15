import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
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
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

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
    return product.copyWith(
      price: override.priceOverride ?? product.price,
    );
  }

  ProductModel _fromRpcRow(Map<String, dynamic> row) => ProductModel(
        id: Db.text(row['id']),
        name: Db.textOrNull(row['name_en']) ?? '',
        nameAr: Db.textOrNull(row['name_ar']),
        nameEn: Db.textOrNull(row['name_en']),
        description: Db.textOrNull(row['description_en']) ?? '',
        descriptionAr: Db.textOrNull(row['description_ar']),
        descriptionEn: Db.textOrNull(row['description_en']),
        category: Db.textOrNull(row['category_name_en']) ?? '',
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
            .select('*')
            .range(offset, offset + limit - 1)
            .order('sort_order', ascending: true)
        : _client
            .from('products')
            .select('*')
            .eq('category_id', categoryId)
            .range(offset, offset + limit - 1)
            .order('sort_order', ascending: true));
    if (rows.isEmpty) return [];

    final prices = await _branchPrices(
      rows.map((r) => r['id'].toString()).toList(),
      branchId,
    );
    return rows
        .map((r) => _withBranch(ProductModel.fromJson(r), prices))
        .toList();
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    final rows =
        await _client.from('products').select('*').eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    final product = ProductModel.fromJson(rows.first);
    final prices = await _branchPrices([product.id], branchId);
    return _withBranch(product, prices);
  }

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) async {
    final product = await getById(id, branchId: branchId);
    if (product == null) return null;

    final links = await _client
        .from('product_option_groups')
        .select('group_id')
        .eq('product_id', id);

    final groupIds = links.map((r) => r['group_id'].toString()).toList();
    if (groupIds.isEmpty) return ProductWithOptions(product: product);

    final groupRows = await _client
        .from('option_groups')
        .select('*')
        .inFilter('id', groupIds);
    final valueRows = await _client
        .from('option_values')
        .select('*')
        .inFilter('group_id', groupIds);

    final valuesByGroup = <String, List<OptionValue>>{};
    for (final v in valueRows) {
      final gid = v['group_id'].toString();
      valuesByGroup.putIfAbsent(gid, () => []).add(OptionValue.fromJson(v));
    }
    for (final list in valuesByGroup.values) {
      list.sort((a, b) => a.code.compareTo(b.code));
    }

    final groups = groupRows
        .map((g) {
          final parsed = OptionGroup.fromJson(g);
          return OptionGroup(
            id: parsed.id,
            code: parsed.code,
            nameAr: parsed.nameAr,
            nameEn: parsed.nameEn,
            isSingleSelect: parsed.isSingleSelect,
            minSelect: parsed.minSelect,
            maxSelect: parsed.maxSelect,
            isRequired: parsed.isRequired,
            values: valuesByGroup[g['id'].toString()] ?? const [],
          );
        })
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    final imageRows = await _client
        .from('product_images')
        .select('*')
        .eq('product_id', id)
        .order('sort_order', ascending: true);

    return ProductWithOptions(
      product: product,
      groups: groups,
      images: imageRows.map(ProductImage.fromJson).toList(),
    );
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
    final rows = await _client.rpc('search_products', params: {
      if (query.trim().isNotEmpty) 'p_query': query.trim(),
      // Optional parameters may be omitted; p_branch_id is optional here so
      // omitting it is correct and lets the server fall back to base prices.
      if (branchId != null) 'p_branch_id': branchId,
      if (categoryId != null) 'p_category_id': categoryId,
      'p_sort': sort,
      'p_page': (offset ~/ limit) + 1,
      'p_page_size': limit,
    });
    return (rows as List).map((r) => _fromRpcRow(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) async {
    final rows = await _client.rpc('get_featured', params: {
      // p_branch_id has no default on the server, so it must always be sent.
      // Passing null explicitly is different from omitting the key: omission
      // makes PostgREST fail to match the signature (PGRST202).
      'p_branch_id': branchId,
      'p_limit': limit,
    });
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return FeaturedProduct(
        productId: Db.text(m['product_id']),
        nameAr: Db.text(m['name_ar']),
        nameEn: Db.text(m['name_en']),
        imageUrl: Db.textOrNull(m['image_url']),
        effectivePrice: Db.asDouble(m['effective_price']),
        source: Db.text(m['source'], 'manual'),
      );
    }).toList();
  }

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) async {
    final rows = await _client.rpc('get_best_sellers', params: {
      'p_branch_id': branchId,
      'p_period': '${period.inDays} days',
      'p_limit': limit,
    });
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
    final rows = await _client.rpc('resolve_effective_price', params: {
      'p_branch_id': branchId,
      'p_product_id': productId,
      'p_option_value_ids': optionValueIds,
    });
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
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('banners')
        .select('*')
        .eq('is_published', true)
        .or('starts_at.is.null,starts_at.lte.$now')
        .or('ends_at.is.null,ends_at.gte.$now')
        .order('sort_order')
        .limit(limit);

    // Resolve the banner target so the detail screen can navigate without
    // matching on a display string.
    final categoryIds = rows
        .where((r) => r['target_type'] == 'category')
        .map((r) => r['target_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final names = <String, String>{};
    if (categoryIds.isNotEmpty) {
      final cats = await _client
          .from('categories')
          .select('id, name_en, name_ar')
          .inFilter('id', categoryIds);
      for (final c in cats) {
        names[c['id'].toString()] = Db.text(c['name_en']);
      }
    }

    return rows.map((r) {
      final enriched = Map<String, dynamic>.from(r);
      final targetId = r['target_id']?.toString();
      if (r['target_type'] == 'category' && targetId != null) {
        enriched['target_category_name'] = names[targetId] ?? '';
      }
      return BannerModel.fromJson(enriched);
    }).toList();
  }

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) async {
    final rows = await _client
        .from('bundles')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')
        .limit(limit);
    if (rows.isEmpty) return [];

    final bundleIds = rows.map((r) => r['id'].toString()).toList();
    final items = await _client
        .from('bundle_items')
        .select('*, product:products(id, name_ar, name_en, image_url)')
        .inFilter('bundle_id', bundleIds)
        .order('sort_order');

final byBundle = <String, List<BundleComponent>>{};
    for (final row in items) {
      final bundleId = row['bundle_id'].toString();
      final product = row['product'];
      final embedded = product is Map ? product : const <String, dynamic>{};
      byBundle.putIfAbsent(bundleId, () => []).add(BundleComponent(
            productId: Db.text(row['product_id']),
            quantity: Db.asInt(row['quantity'], fallback: 1),
            allowOptions: row['allow_options'] == true,
            nameAr: Db.textOrNull(embedded['name_ar']),
            nameEn: Db.textOrNull(embedded['name_en']),
            imageUrl: Db.textOrNull(embedded['image_url']),
          ));
    }

    return rows
        .map((r) => BundleModel.fromJson(
              r,
              components: byBundle[r['id'].toString()] ?? const [],
            ))
        .toList();
  }

  // --- CategoryRepository --------------------------------------------------

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) async {
    // Built in one expression: the PostgREST builder changes type after each
    // filter, so reassigning a `var` across filters does not type check.
    final rows = await (includeInactive
        ? _client.from('categories').select('*').order('sort_order')
        : _client
            .from('categories')
            .select('*')
            .eq('is_active', true)
            .order('sort_order'));
    return rows.map(CategoryModel.fromJson).toList();
  }

  @override
  Future<CategoryModel?> getCategoryById(String id) async {
    final rows = await _client.from('categories').select('*').eq('id', id).limit(1);
    return rows.isEmpty ? null : CategoryModel.fromJson(rows.first);
  }

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) async {
    final rows =
        await _client.from('categories').select('*').eq('slug', slug).limit(1);
    return rows.isEmpty ? null : CategoryModel.fromJson(rows.first);
  }

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) async {
    final rows = await _client
        .from('categories')
        .select('*')
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