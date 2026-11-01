import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// Read access to the product catalogue.
///
/// Declared against behaviour, not against Supabase. Screens and cubits depend
/// only on this, so the data source can be swapped without touching a widget.
/// Two implementations ship: one that reads the database, one that reads the
/// old Dart constants so the app stays runnable when Supabase is not configured.
/// How many rows a catalogue read returns when the caller does not say.
///
/// The interface and each implementation used to repeat these numbers, so a
/// default could drift between the database reader and a test double without
/// anything noticing.
abstract final class CatalogLimits {
  static const int products = 100;
  static const int search = 20;
  static const int featured = 10;
  static const int bestSellers = 10;
  static const int banners = 20;
  static const int bundles = 20;
}

abstract class ProductRepository {
  /// The catalogue for a branch, with branch pricing already applied.
  ///
  /// [branchId] selects the price and availability the customer would actually
  /// be charged. When it is null the base price is returned.
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  });

  Future<ProductModel?> getById(String id, {String? branchId});

  /// Everything a product detail screen needs: the product plus the option
  /// groups bound to it and their values.
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId});

  /// Option groups bound to many products, in one round trip.
  ///
  /// The assistant needs the size and sugar groups of the whole menu to build
  /// a cart action. Reading them product by product costs about six queries per
  /// product, so opening the assistant cost dozens of requests; this costs
  /// three for the entire catalogue.
  ///
  /// An empty [productIds] asks for every product, which lets the caller start
  /// the read before it knows the ids and run it alongside the product query.
  Future<Map<String, List<OptionGroup>>> getOptionsByProduct(
    List<String> productIds,
  );

  /// Server-side search. Arabic works because the aliases live in the database
  /// rather than in a Dart map, so search no longer borrows from the assistant.
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = CatalogLimits.search,
    int offset = 0,
  });

  /// Manual is_featured first, then best sellers. Each row carries a `source`
  /// so the UI can explain why a product is shown.
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = CatalogLimits.featured,
  });

  /// Ranked from completed orders inside a period. Returns an empty list while
  /// there is no sales history, which is a valid answer rather than an error.
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = CatalogLimits.bestSellers,
  });

  /// Branch-specific price for one product, resolved on the server.
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  });

  /// Published home banners, already inside their display window.
  ///
  /// The window filter runs on the server so an expired banner never reaches
  /// the client at all.
  Future<List<BannerModel>> getBanners({int limit = CatalogLimits.banners});

  /// Active bundles with their components and quantities resolved.
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = CatalogLimits.bundles,
  });

  /// One bundle by id, with components resolved. Null when not found.
  Future<BundleModel?> getBundleById(String id);
}

/// A product together with the options bound to it.
class ProductWithOptions {
  const ProductWithOptions({
    required this.product,
    this.groups = const [],
    this.images = const [],
  });

  final ProductModel product;

  /// Option groups offered by this product, each with its selectable values.
  final List<OptionGroup> groups;

  final List<ProductImage> images;
}

class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.isSingleSelect,
    required this.minSelect,
    required this.maxSelect,
    required this.isRequired,
    required this.values,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool isSingleSelect;
  final int minSelect;
  final int? maxSelect;
  final bool isRequired;
  final List<OptionValue> values;

  /// Display order chosen by the admin. Sorting on `code` instead would render
  /// the sizes as Large, Medium, Small.
  final int sortOrder;

  String get name {
    final localized = pickText((
      ar: nameAr,
      en: nameEn,
    ), isArabic: AppLocale.instance.isArabic);
    return localized.isEmpty ? code : localized;
  }

  /// Replaces the frozen DrinkSize and SugarLevel enums.
  factory OptionGroup.fromJson(Map<String, dynamic> json) => OptionGroup(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    nameAr: json['name_ar']?.toString() ?? '',
    nameEn: json['name_en']?.toString() ?? '',
    isSingleSelect: json['selection_type'] == 'single',
    minSelect: (json['min_select'] as num?)?.toInt() ?? 0,
    maxSelect: (json['max_select'] as num?)?.toInt(),
    isRequired: json['is_required'] == true,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    values: const [],
  );
}

class OptionValue {
  const OptionValue({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.priceDelta,
    this.shortLabel,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final double priceDelta;
  final String? shortLabel;
  final bool isDefault;

  /// Admin-defined display order, so sizes render Small, Medium, Large rather
  /// than alphabetically.
  final int sortOrder;

  String get name {
    final localized = pickText((
      ar: nameAr,
      en: nameEn,
    ), isArabic: AppLocale.instance.isArabic);
    return localized.isEmpty ? code : localized;
  }

  factory OptionValue.fromJson(Map<String, dynamic> json) => OptionValue(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    nameAr: json['name_ar']?.toString() ?? '',
    nameEn: json['name_en']?.toString() ?? '',
    priceDelta: (json['price_delta'] as num?)?.toDouble() ?? 0,
    shortLabel: json['short_label']?.toString(),
    isDefault: json['is_default'] == true,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}

OptionGroup effectiveProductOptionGroup({
  required OptionGroup group,
  required bool bindingIsRequired,
  required int bindingSortOrder,
  required List<OptionValue> values,
}) {
  final isRequired = bindingIsRequired || group.isRequired;
  return OptionGroup(
    id: group.id,
    code: group.code,
    nameAr: group.nameAr,
    nameEn: group.nameEn,
    isSingleSelect: group.isSingleSelect,
    minSelect: isRequired && group.minSelect < 1 ? 1 : group.minSelect,
    maxSelect: group.maxSelect,
    isRequired: isRequired,
    sortOrder: bindingSortOrder > 0 ? bindingSortOrder : group.sortOrder,
    values: values,
  );
}

class ProductImage {
  const ProductImage({
    required this.url,
    this.altAr,
    this.altEn,
    this.isPrimary = false,
    this.sortOrder = 0,
    this.fit = 'cover',
    this.alignment = 'center',
  });

  final String url;
  final String? altAr;
  final String? altEn;
  final bool isPrimary;
  final int sortOrder;

  /// How the picture fills its space, as the dashboard set it.
  final String fit;

  /// Where the picture sits in its space, as the dashboard set it.
  final String alignment;

  factory ProductImage.fromJson(Map<String, dynamic> json) => ProductImage(
    url: json['image_url']?.toString() ?? '',
    altAr: json['alt_ar']?.toString(),
    altEn: json['alt_en']?.toString(),
    isPrimary: json['is_primary'] == true,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    fit: json['fit']?.toString() ?? 'cover',
    alignment: json['alignment']?.toString() ?? 'center',
  );
}

class FeaturedProduct {
  const FeaturedProduct({
    required this.productId,
    required this.nameAr,
    required this.nameEn,
    this.imageUrl,
    required this.effectivePrice,
    required this.source,
    this.categoryAr,
    this.categoryEn,
    this.regularPrice,
    this.discountPercentage = 0,
  });

  final String productId;
  final String nameAr;
  final String nameEn;
  final String? imageUrl;
  final double effectivePrice;

  /// The price the discount was taken from. Null when the server did not say.
  final double? regularPrice;

  /// The discount the server applied, in percent. Zero when there is none.
  final double discountPercentage;

  /// Whether this product really carries a discount.
  bool get hasDiscount => discountPercentage > 0 && regularPrice != null;

  /// Category name, so a card can label itself without a second query. Null
  /// when the product has no category.
  final String? categoryAr;
  final String? categoryEn;

  String get name =>
      pickText((ar: nameAr, en: nameEn), isArabic: AppLocale.instance.isArabic);

  /// 'manual' when the admin pinned it, 'best_seller' when the ranking chose it.
  final String source;
}

class BestSeller {
  const BestSeller({
    required this.productId,
    required this.nameAr,
    required this.nameEn,
    required this.unitsSold,
    required this.revenue,
    this.imageUrl,
  });

  final String productId;
  final String nameAr;
  final String nameEn;
  final int unitsSold;
  final double revenue;
  final String? imageUrl;

  String get name =>
      pickText((ar: nameAr, en: nameEn), isArabic: AppLocale.instance.isArabic);
}

class ResolvedPrice {
  const ResolvedPrice({
    required this.unitPrice,
    required this.currencyCode,
    required this.isAvailable,
    this.unavailableReason,
    this.regularPrice,
    this.discountPercentage = 0,
  });

  final double unitPrice;

  /// The price before the discount, when one applies.
  final double? regularPrice;

  /// The discount the server applied, in percent. Zero when there is none.
  final double discountPercentage;

  final String currencyCode;
  final bool isAvailable;
  final String? unavailableReason;

  /// Whether a discount really applies to this price.
  bool get hasDiscount =>
      discountPercentage > 0 &&
      regularPrice != null &&
      regularPrice! > unitPrice;
}

/// Category reads, kept separate so a category listing never has to pull the
/// whole catalogue to render a grid.
///
/// Names are prefixed because a single class implements this alongside
/// [ProductRepository], and `getById` would otherwise be an ambiguous override.
abstract class CategoryRepository {
  Future<List<CategoryModel>> getCategories({bool includeInactive = false});

  Future<CategoryModel?> getCategoryById(String id);

  Future<CategoryModel?> getCategoryBySlug(String slug);

  /// Sub-categories of a parent. The old CategoryModel had no id at all, so the
  /// app could never express this.
  Future<List<CategoryModel>> getCategoryChildren(String parentId);
}

/// The catalogue as a single dependency.
///
/// Products and categories are separate concerns, but they come from the same
/// tables and are always read together, so the app injects one instance under
/// both types rather than building two that could disagree.
abstract class CatalogRepository
    implements ProductRepository, CategoryRepository {}
