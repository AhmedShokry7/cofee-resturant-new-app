import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_read_service.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/data/model/banner_links.dart';
import 'package:new_coffee/features/home/data/repositories/banner_link_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the catalogue from Supabase.
///
/// Talks to the `public` routing views created in 032 and to the RPCs in 035.
/// Those views are declared WITH (security_invoker = true), so every query here
/// runs under the caller's own role and the catalogue RLS policies decide the
/// rows. Nothing here needs a privileged key, and the service_role key is never
/// referenced.
class SupabaseProductRepository
    implements CatalogRepository, BatchProductRepository, BannerLinkRepository {
  SupabaseProductRepository([SupabaseClient? client])
    : _client = client ?? SupabaseReadService.read;

  final SupabaseClient _client;

  // Explicit column lists instead of select('*'): the client asks for exactly
  // what its models read, so a future column on the table can never leak into
  // the app or break a parser by surprise.
  static const _productColumns =
      'id, category_id, sku, slug, name_ar, name_en, description_ar, '
      'description_en, base_price, compare_at_price, image_url, is_featured, '
      'discount_percentage, discount_starts_at, discount_ends_at, '
      'prep_minutes, calories, category_slug, category_name_ar, category_name_en, '
      'related_product_ids';

  static const _productImageColumns =
      'id, product_id, image_url, alt_ar, alt_en, is_primary, sort_order, fit, alignment';

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
        .select(
          'product_id, price_override, is_available, unavailable_reason, '
          'discount_percentage, discount_starts_at, discount_ends_at, '
          'use_general_discount',
        )
        .eq('branch_id', branchId)
        .inFilter('product_id', productIds);

    return {
      for (final r in rows)
        r['product_id']?.toString() ?? '': _BranchPrice(
          priceOverride: Db.asDoubleOrNull(r['price_override']),
          isAvailable: r['is_available'] == true,
          reason: Db.textOrNull(r['unavailable_reason']),
          discountPercentage: Db.asDoubleOrNull(r['discount_percentage']),
          discountStartsAt: r['discount_starts_at'] == null
              ? null
              : DateTime.tryParse('${r['discount_starts_at']}'),
          discountEndsAt: r['discount_ends_at'] == null
              ? null
              : DateTime.tryParse('${r['discount_ends_at']}'),
          useGeneralDiscount: r['use_general_discount'] != false,
        ),
    };
  }

  /// The price the server stores is rounded to two decimals
  /// (catalog.resolve_effective_price rounds with round(..., 2)).
  ///
  /// The client has to round the same way, otherwise the cart shows a total
  /// that is a fraction of a cent away from the invoice the server writes, and
  /// the checkout loses the coupon row when the two subtotals drift apart.
  static double _round2(double value) => double.parse(value.toStringAsFixed(2));

  bool _isActiveDiscount(double? percentage, DateTime? start, DateTime? end) {
    if (percentage == null || percentage <= 0) return false;
    final now = DateTime.now();
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  ProductModel _withBranch(
    ProductModel product,
    Map<String, _BranchPrice> prices,
  ) {
    final override = prices[product.id];

    if (override == null) {
      final generalPct =
          _isActiveDiscount(
            product.discountPercentage,
            product.discountStartsAt,
            product.discountEndsAt,
          )
          ? product.discountPercentage!
          : 0.0;
      if (generalPct <= 0) {
        return product.copyWith(clearAppliedDiscountPercentage: true);
      }
      return product.copyWith(
        price: _round2(product.price * (1 - generalPct / 100.0)),
        oldPrice: product.price,
        appliedDiscountPercentage: generalPct,
      );
    }

    final regular = override.priceOverride ?? product.price;

    final branchPct =
        _isActiveDiscount(
          override.discountPercentage,
          override.discountStartsAt,
          override.discountEndsAt,
        )
        ? override.discountPercentage!
        : null;

    final generalPct =
        _isActiveDiscount(
          product.discountPercentage,
          product.discountStartsAt,
          product.discountEndsAt,
        )
        ? product.discountPercentage!
        : null;

    final pct =
        branchPct ?? (override.useGeneralDiscount ? (generalPct ?? 0.0) : 0.0);

    if (pct <= 0) {
      return product.copyWith(
        price: regular,
        clearAppliedDiscountPercentage: true,
      );
    }
    return product.copyWith(
      price: _round2(regular * (1 - pct / 100.0)),
      oldPrice: regular,
      appliedDiscountPercentage: pct,
    );
  }

  /// Builds a product from a search row.
  ///
  /// The row carries the price the server applied, the regular price it came
  /// from and the discount that produced it, so the badge shows the discount
  /// that is really on this product.
  ProductModel _fromRpcRow(Map<String, dynamic> row) {
    final effective = Db.asDouble(row['effective_price'] ?? row['base_price']);
    final regular = Db.asDoubleOrNull(row['regular_price']);
    final percent = Db.asDoubleOrNull(row['discount_percentage']) ?? 0;
    final discounted = percent > 0 && regular != null;
    return ProductModel(
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
      price: effective,
      oldPrice: discounted ? regular : null,
      appliedDiscountPercentage: discounted ? percent : null,
      image: Db.textOrNull(row['image_url']) ?? '',
      isFeatured: row['rank'] != null,
      calories: row['calories'] == null ? null : Db.asInt(row['calories']),
    );
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
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
    final results = await Future.wait<Object>(<Future<Object>>[
      imageRowsFuture,
      pricesFuture,
    ], eagerError: true);
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
          final primary = _determinePrimaryImage(images);
          final primaryImageUrl =
              primary?.url ??
              (product.image.trim().isEmpty ? null : product.image.trim());
          return product.copyWith(
            imageUrls: imageUrls.isNotEmpty ? imageUrls : const [],
            primaryImageUrl: primaryImageUrl,
            isPrimaryImageAvailable: primaryImageUrl != null,
            // The dashboard decides how the picture of the product is shown.
            imageFit: primary?.fit ?? 'cover',
            imageAlignment: primary?.alignment ?? 'center',
          );
        })
        .toList()
        .map((product) => _withBranch(product, prices))
        .toList();
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async =>
      (await _loadWithImages(id, branchId: branchId))?.product;

  /// The product row together with the gallery that was read for it.
  ///
  /// The details screen needs both, and used to ask for the gallery a second
  /// time right after [getById] had already fetched it.
  Future<({ProductModel product, List<ProductImage> images})?> _loadWithImages(
    String id, {
    String? branchId,
  }) async {
    final rows = await _client
        .from('products')
        .select(_productColumns)
        .eq('id', id)
        .limit(1);
    if (rows.isEmpty) return null;
    final images = await _productImages(id);
    final product = _withPrimaryImage(
      ProductModel.fromJson(rows.first),
      images,
    );
    final prices = await _branchPrices([product.id], branchId);
    return (product: _withBranch(product, prices), images: images);
  }

  @override
  Future<List<ProductModel>> getByIds(
    List<String> ids, {
    String? branchId,
  }) async {
    final productIds = ids.toSet().toList(growable: false);
    if (productIds.isEmpty) return const [];

    final rows = await _client.rpc(
      'catalog_products_by_ids',
      params: <String, dynamic>{
        'p_product_ids': productIds,
        'p_branch_id': ?branchId,
      },
      // The function is STABLE and performs no writes, so GET is safe on a
      // Supabase read replica endpoint as well as on the primary.
      get: true,
    ) as List;
    if (rows.isEmpty) return const [];
    return rows
        .map((rawRow) {
          final row = Map<String, dynamic>.from(rawRow as Map);
          final product = ProductModel.fromJson(
            Map<String, dynamic>.from(row['product'] as Map),
          );
          final rawImages = row['images'];
          final images = rawImages is List
              ? rawImages
                    .whereType<Map>()
                    .map(
                      (image) => ProductImage.fromJson(
                        Map<String, dynamic>.from(image),
                      ),
                    )
                    .toList()
              : const <ProductImage>[];
          final imageUrls = images.map((image) => image.url).toList();
          final primary = _determinePrimaryImage(images);
          final primaryImageUrl =
              primary?.url ??
              (product.image.trim().isEmpty ? null : product.image.trim());
          // The server states the price it applied and the discount that
          // produced it, so the badge carries the real percentage instead of
          // one guessed from two prices.
          final effective = Db.asDouble(
            row['effective_price'],
            fallback: product.price,
          );
          final regular = Db.asDoubleOrNull(row['regular_price']);
          final percent = Db.asDoubleOrNull(row['discount_percentage']) ?? 0;
          final discounted = percent > 0 && regular != null;
          return product.copyWith(
            price: effective,
            oldPrice: discounted ? regular : product.oldPrice,
            appliedDiscountPercentage: discounted ? percent : null,
            clearAppliedDiscountPercentage: !discounted,
            imageUrls: imageUrls,
            primaryImageUrl: primaryImageUrl,
            isPrimaryImageAvailable: primaryImageUrl != null,
            imageFit: primary?.fit ?? product.imageFit,
            imageAlignment: primary?.alignment ?? product.imageAlignment,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<ProductWithOptions?> getWithOptions(
    String id, {
    String? branchId,
  }) async {
    // The product row and its option bindings do not depend on each other, so
    // they are fetched together rather than one round trip after another.
    final loadedFuture = _loadWithImages(id, branchId: branchId);
    final linksFuture = _client
        .from('product_option_groups')
        .select('group_id, sort_order, is_required')
        .eq('product_id', id);

    final loaded = await loadedFuture;
    final links = await linksFuture;
    if (loaded == null) return null;
    final product = loaded.product;
    final images = loaded.images;

    final bindingByGroup = {
      for (final link in links) link['group_id'].toString(): link,
    };
    final groupIds = bindingByGroup.keys.toList();
    if (groupIds.isEmpty) {
      return ProductWithOptions(product: product, images: images);
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

    return ProductWithOptions(product: product, groups: groups, images: images);
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
    final linksFuture = productIds.isEmpty
        ? _client
              .from('product_option_groups')
              .select('product_id, group_id, sort_order, is_required')
              .limit(2000)
        : _client
              .from('product_option_groups')
              .select('product_id, group_id, sort_order, is_required')
              .inFilter('product_id', productIds)
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
      byProduct
          .putIfAbsent(productId, () => [])
          .add(
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

  /// The product with the picture it is shown with, and the way it is shown.
  ///
  /// The primary picture wins, otherwise the first picture by sort order. When
  /// the product has no picture rows the product-level image is the fallback.
  static ProductModel _withPrimaryImage(
    ProductModel product,
    List<ProductImage> images,
  ) {
    final imageUrls = images.map((image) => image.url).toList(growable: false);
    final primary = _determinePrimaryImage(images);
    final primaryImageUrl =
        primary?.url ??
        (product.image.trim().isEmpty ? null : product.image.trim());
    return product.copyWith(
      imageUrls: imageUrls,
      primaryImageUrl: primaryImageUrl,
      isPrimaryImageAvailable: primaryImageUrl != null,
      imageFit: primary?.fit ?? product.imageFit,
      imageAlignment: primary?.alignment ?? product.imageAlignment,
    );
  }

  Future<List<ProductImage>> _productImages(String productId) async {
    final rows = await _client
        .from('product_images')
        .select(_productImageColumns)
        .eq('product_id', productId)
        .order('sort_order', ascending: true);
    return rows.map(ProductImage.fromJson).toList();
  }

  /// The picture the product is shown with, and the way it is shown.
  ///
  /// The picture is the one marked as primary, or the one with the lowest
  /// sort_order. The display settings come with it, so the product looks the
  /// same in the list, in the card and in the details.
  static ProductImage? _determinePrimaryImage(List<ProductImage> images) {
    // 1. Image explicitly marked as primary.
    final primary = images.firstWhere(
      (img) => img.isPrimary,
      orElse: () => ProductImage(url: '', isPrimary: false),
    );
    if (primary.isPrimary && primary.url.isNotEmpty) {
      return primary;
    }

    // 2. Otherwise, the image with the lowest sort_order.
    final sorted = images..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (sorted.isNotEmpty && sorted.first.url.isNotEmpty) {
      return sorted.first;
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
    int limit = CatalogLimits.search,
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
    int limit = CatalogLimits.featured,
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
        regularPrice: Db.asDoubleOrNull(m['regular_price']),
        discountPercentage: Db.asDoubleOrNull(m['discount_percentage']) ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = CatalogLimits.bestSellers,
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
      regularPrice: Db.asDoubleOrNull(m['regular_price']),
      discountPercentage: Db.asDoubleOrNull(m['discount_percentage']) ?? 0,
    );
  }

  // --- Home page content ---------------------------------------------------

  /// `sort_order` is an ascending display column - the dashboard puts the banner
  /// the customer should see first at 0 - but the PostgREST builder defaults to
  /// DESCENDING, so every `sort_order` order in this file says `ascending:
  /// true` explicitly. Without it the carousel opened on the last banner and
  /// the promo slot below it repeated the first one.

  @override
  Future<List<BannerModel>> getBanners({
    int limit = CatalogLimits.banners,
  }) async {
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
        .order('sort_order', ascending: true)
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
  Future<BannerLinks> getBannerLinks(String bannerId) async {
    // The two link tables are read together: neither answer feeds the other,
    // and a banner page that waited for one after the other would pay for two
    // round trips to draw one strip.
    Future<List<Map<String, dynamic>>> links(String table, String column) =>
        _client
            .from(table)
            .select('$column,sort_order')
            .eq('banner_id', bannerId)
            .order('sort_order', ascending: true);

    try {
      final both = await Future.wait([
        links('banner_products', 'product_id'),
        links('banner_categories', 'category_id'),
      ]);
      return BannerLinks.fromRows(
        productRows: both[0],
        categoryRows: both[1],
      );
    } on PostgrestException catch (error) {
      // PGRST205 is "no such table or view", which is what a database where
      // migration 222 has not been applied yet answers. The banner keeps the
      // single row behind its own target_id instead of opening on an error.
      if (error.code == 'PGRST205') return BannerLinks.none;
      rethrow;
    }
  }

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = CatalogLimits.bundles,
  }) async {
    final rows = await _client
        .from('bundles')
        .select(_bundleColumns)
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .limit(limit);
    if (rows.isEmpty) return [];

    final bundleIds = rows.map((r) => r['id'].toString()).toList();
    final items = await _client
        .from('bundle_items')
        .select(_bundleItemColumns)
        .inFilter('bundle_id', bundleIds)
        .order('sort_order', ascending: true);

    final byBundle = _componentsByBundle(items);

    return rows
        .map(
          (r) => BundleModel.fromJson(
            r,
            components: byBundle[r['id'].toString()] ?? const [],
          ),
        )
        .toList();
  }

  /// Bundle component rows grouped by the bundle they belong to.
  ///
  /// Both bundle reads used to rebuild this map with their own copy of the
  /// loop, so a new component column had to be added twice.
  Map<String, List<BundleComponent>> _componentsByBundle(List rows) {
    final byBundle = <String, List<BundleComponent>>{};
    for (final row in rows) {
      final product = row['product'];
      final embedded = product is Map ? product : const <String, dynamic>{};
      byBundle
          .putIfAbsent(row['bundle_id'].toString(), () => [])
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
    return byBundle;
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
        .order('sort_order', ascending: true);

    return BundleModel.fromJson(
      bundle,
      components: _componentsByBundle(items)[bundleId] ?? const [],
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
              .order('sort_order', ascending: true)
        : _client
              .from('categories')
              .select(_categoryColumns)
              .eq('is_active', true)
              .order('sort_order', ascending: true));
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
        .order('sort_order', ascending: true);
    return rows.map(CategoryModel.fromJson).toList();
  }
}

class _BranchPrice {
  const _BranchPrice({
    required this.isAvailable,
    this.priceOverride,
    this.reason,
    this.discountPercentage,
    this.discountStartsAt,
    this.discountEndsAt,
    this.useGeneralDiscount = true,
  });

  final double? priceOverride;
  final bool isAvailable;
  final String? reason;
  final double? discountPercentage;
  final DateTime? discountStartsAt;
  final DateTime? discountEndsAt;
  final bool useGeneralDiscount;
}
