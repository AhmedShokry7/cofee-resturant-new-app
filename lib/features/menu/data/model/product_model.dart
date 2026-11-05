import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A product.
///
/// [nameAr] and [nameEn] are the source of truth (decision D4: the database
/// stores both). [name] and [description] are locale-aware getters, so the
/// roughly fifty existing call sites keep working untouched while the data
/// behind them becomes bilingual.
class ProductModel {
  const ProductModel({
    required this.id,
    String? name,
    String? category,
    String? description,
    required this.price,
    this.oldPrice,
    required this.image,
    this.nameAr,
    this.nameEn,
    this.nameCopy,
    this.categoryAr,
    this.categoryEn,
    this.descriptionAr,
    this.descriptionEn,
    this.slug,
    this.sku,
    this.categoryId,
    this.categorySlug = '',
    this.isFeatured = false,
    this.prepMinutes,
    this.calories,
    this.discountPercentage,
    this.discountStartsAt,
    this.discountEndsAt,
    this.appliedDiscountPercentage,
    this.imageUrls = const [],
    this.isPrimaryImageAvailable = false,
    this.primaryImageUrl,
    this.imageFit = 'cover',
    this.imageAlignment = 'center',
    this.relatedProductIds = const [],
  }) : _legacyName = name ?? '',
       _legacyCategory = category ?? '',
       _legacyDescription = description ?? '';

  final String id;

  /// Arabic name. Falls back to [nameEn] when absent.
  final String? nameAr;

  /// English name. Falls back to [nameAr] when absent.
  final String? nameEn;

  /// The name a line the app created for itself should read as.
  ///
  /// A cart line for a product that left the branch has no bilingual pair, so
  /// its words come from a token: read when the screen asks, the line changes
  /// language with everything else instead of keeping the language the cart
  /// happened to be built in.
  final AppCopy? nameCopy;

  final String? categoryAr;
  final String? categoryEn;

  /// Category id from `catalog.categories`. Null for legacy mock data, which
  /// only ever had the category label.
  final String? categoryId;

  /// Stable category key, e.g. `hot-coffee`.
  ///
  /// Business rules must match on this rather than on [category]: [category] is
  /// a display name, so a rename or a translation would silently break any rule
  /// comparing against it. Empty only for legacy mock products.
  final String categorySlug;

  final String? slug;
  final String? sku;

  final String? descriptionAr;
  final String? descriptionEn;

  final double price;
  final double? oldPrice;
  final String image;

  final bool isFeatured;
  final int? prepMinutes;

  /// Scheduled general discount of the product, in percent.
  final double? discountPercentage;

  /// Start of the general discount window.
  final DateTime? discountStartsAt;

  /// End of the general discount window.
  final DateTime? discountEndsAt;

  /// The discount that is applied to [price] right now, in percent.
  ///
  /// Null when the product is not discounted. Nothing displays this number —
  /// the pages show the price before and after the discount — but it is the
  /// server's own word on the matter, so a discount can never be invented from
  /// two prices that happen to differ.
  ///
  /// It is set by the repository, which is the only place that knows whether
  /// the discount of the product, the discount of the branch, or the window of
  /// either one is active at this moment. [discountPercentage] is the
  /// configured value and says nothing about whether it applies.
  final double? appliedDiscountPercentage;

  /// Calories per serving, in kcal. Null means the value has not been provided.
  final int? calories;

  // Single-language values carried over from the mock data. They keep `name`,
  // `category` and `description` working as getters, so the roughly fifty
  // existing call sites need no change while the data becomes bilingual.
  final String _legacyName;
  final String _legacyCategory;
  final String _legacyDescription;

  /// List of product image URLs from the database, ordered by sort_order.
  final List<String> imageUrls;

  /// Whether a primary image is available.
  final bool isPrimaryImageAvailable;

  /// The primary image URL, determined by priority: explicit is_primary → lowest sort_order → product-level image → null.
  final String? primaryImageUrl;

  /// How the picture of the product fills its space, as the dashboard set it.
  final String imageFit;

  /// Where the picture of the product sits in its space, as the dashboard set
  /// it.
  final String imageAlignment;

  /// Admin-defined companion products for "Goes well with".
  final List<String> relatedProductIds;

  /// First usable product image, with legacy and secondary-image fallbacks.
  String? get displayImageUrl {
    for (final candidate in [primaryImageUrl, ...imageUrls, image]) {
      final url = candidate?.trim();
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  /// Category label as a plain string. Still the join key for the mock data and
  /// for anything that has not moved to ids yet.
  String get category {
    final ar = categoryAr ?? '';
    final en = categoryEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) return _legacyCategory;
    return pickText((ar: ar, en: en), isArabic: isArabic);
  }

  bool get isArabic => AppLocale.instance.isArabic;

  String get name {
    final ar = nameAr ?? '';
    final en = nameEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) {
      return _legacyName.isNotEmpty ? _legacyName : (nameCopy?.copy ?? '');
    }
    return pickText((ar: ar, en: en), isArabic: isArabic);
  }

  String get description {
    final ar = descriptionAr ?? '';
    final en = descriptionEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) return _legacyDescription;
    return pickText((ar: ar, en: en), isArabic: isArabic);
  }

  /// Whether a real discount is applied to [price].
  ///
  /// This is deliberately not "the old price is higher than the price": the
  /// admin's compare-at price is a merchandising price, and reading it as a
  /// discount made a product with no discount at all announce a percentage.
  bool get hasDiscount =>
      appliedDiscountPercentage != null && appliedDiscountPercentage! > 0;

  /// Whether an old price is shown next to [price].
  ///
  /// True for a discounted product (the price before the discount) and for a
  /// product that only carries a compare-at price. The second case shows the
  /// old price as a reference, not as a promotion.
  bool get hasOldPrice => oldPrice != null && oldPrice! > price;

  /// Convenience for the search ranking UI.
  bool matches(String needle) {
    final q = needle.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q);
  }

  /// Reads a row from `catalog.products`, joined with its category.
  ///
  /// Accepts the snake_case column names PostgREST returns, and also tolerates
  /// the camelCase names used by RPCs so one constructor serves both.
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final categoryName =
        Db.textOrNull(json['category_name']) ??
        Db.textOrNull(json['category']) ??
        '';
    return ProductModel(
      id: Db.text(json['id']),
      name:
          Db.textOrNull(json['name_en']) ??
          Db.textOrNull(json['name']) ??
          Db.textOrNull(json['name_ar']) ??
          '',
      nameAr: Db.textOrNull(json['name_ar']),
      nameEn: Db.textOrNull(json['name_en']),
      categoryAr:
          Db.textOrNull(json['category_name_ar']) ??
          Db.textOrNull(json['category_ar']),
      categoryEn:
          Db.textOrNull(json['category_name_en']) ??
          Db.textOrNull(json['category_en']),
      description:
          Db.textOrNull(json['description_en']) ??
          Db.textOrNull(json['description']) ??
          '',
      descriptionAr: Db.textOrNull(json['description_ar']),
      descriptionEn: Db.textOrNull(json['description_en']),
      category: categoryName,
      categoryId: Db.textOrNull(json['category_id']),
      categorySlug: Db.textOrNull(json['category_slug']) ?? '',
      slug: Db.textOrNull(json['slug']),
      sku: Db.textOrNull(json['sku']),
      price: Db.asDouble(json['base_price'] ?? json['price']),
      oldPrice: Db.asDoubleOrNull(
        json['compare_at_price'] ?? json['old_price'],
      ),
      image:
          Db.textOrNull(json['image_url']) ??
          Db.textOrNull(json['image']) ??
          '',
      isFeatured: Db.asBool(json['is_featured']),
      imageUrls: Db.textOrNull(json['image_urls']) != null
          ? Db.text(json['image_urls']).split(',')
          : const [],
      isPrimaryImageAvailable: Db.asBool(json['is_primary']),
      primaryImageUrl: Db.textOrNull(json['primary_image_url']),
      prepMinutes: json['prep_minutes'] == null
          ? null
          : Db.asInt(json['prep_minutes']),
      discountPercentage: Db.asDoubleOrNull(json['discount_percentage']),
      discountStartsAt: json['discount_starts_at'] == null
          ? null
          : DateTime.tryParse('${json['discount_starts_at']}'),
      discountEndsAt: json['discount_ends_at'] == null
          ? null
          : DateTime.tryParse('${json['discount_ends_at']}'),
      calories: json['calories'] == null ? null : Db.asInt(json['calories']),
      relatedProductIds:
          (json['related_product_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'sku': sku,
    'name_ar': nameAr ?? name,
    'name_en': nameEn ?? name,
    'category_name_ar': categoryAr,
    'category_name_en': categoryEn,
    'description_ar': descriptionAr ?? description,
    'description_en': descriptionEn ?? description,
    'category_id': categoryId,
    'category': category,
    'base_price': price,
    'compare_at_price': oldPrice,
    'image_url': image,
    'is_featured': isFeatured,
    'prep_minutes': prepMinutes,
    'discount_percentage': discountPercentage,
    'discount_starts_at': discountStartsAt?.toIso8601String(),
    'discount_ends_at': discountEndsAt?.toIso8601String(),
    'calories': calories,
    'image_urls': imageUrls.join(','),
    'is_primary': isPrimaryImageAvailable,
    'primary_image_url': primaryImageUrl,
  };

  ProductModel copyWith({
    String? id,
    String? name,
    String? nameAr,
    String? nameEn,
    String? slug,
    String? sku,
    String? categoryAr,
    String? categoryEn,
    String? category,
    String? categoryId,
    String? categorySlug,
    String? description,
    String? descriptionAr,
    String? descriptionEn,
    double? price,
    double? oldPrice,
    String? image,
    bool? isFeatured,
    int? prepMinutes,
    double? discountPercentage,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
    double? appliedDiscountPercentage,
    bool clearAppliedDiscountPercentage = false,
    int? calories,
    List<String>? imageUrls,
    bool? isPrimaryImageAvailable,
    String? primaryImageUrl,
    String? imageFit,
    String? imageAlignment,
    List<String>? relatedProductIds,
  }) => ProductModel(
    id: id ?? this.id,
    name: name ?? this.name,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    slug: slug ?? this.slug,
    sku: sku ?? this.sku,
    categoryAr: categoryAr ?? this.categoryAr,
    categoryEn: categoryEn ?? this.categoryEn,
    category: category ?? this.category,
    categoryId: categoryId ?? this.categoryId,
    categorySlug: categorySlug ?? this.categorySlug,
    description: description ?? this.description,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    price: price ?? this.price,
    oldPrice: oldPrice ?? this.oldPrice,
    image: image ?? this.image,
    isFeatured: isFeatured ?? this.isFeatured,
    prepMinutes: prepMinutes ?? this.prepMinutes,
    discountPercentage: discountPercentage ?? this.discountPercentage,
    discountStartsAt: discountStartsAt ?? this.discountStartsAt,
    discountEndsAt: discountEndsAt ?? this.discountEndsAt,
    appliedDiscountPercentage: clearAppliedDiscountPercentage
        ? null
        : (appliedDiscountPercentage ?? this.appliedDiscountPercentage),
    calories: calories ?? this.calories,
    imageUrls: imageUrls ?? this.imageUrls,
    isPrimaryImageAvailable:
        isPrimaryImageAvailable ?? this.isPrimaryImageAvailable,
    primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
    imageFit: imageFit ?? this.imageFit,
    imageAlignment: imageAlignment ?? this.imageAlignment,
    relatedProductIds: relatedProductIds ?? this.relatedProductIds,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          other.id == id &&
          other.price == price &&
          other.nameAr == nameAr &&
          other.nameEn == nameEn;

  @override
  int get hashCode => Object.hash(id, price, nameAr, nameEn);

  @override
  String toString() => 'ProductModel($id, $name, $price)';
}
