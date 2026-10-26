import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_product_image.dart';

/// A product as the admin dashboard edits it.
///
/// The model mirrors the `catalog.products` row together with the category it
/// belongs to and the stock it holds for the branch the dashboard reviews.
/// Every field is stored in the two panel languages, so the card can show the
/// one that matches the language of the admin panel.
class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.sku,
    required this.slug,
    required this.basePrice,
    this.descriptionAr,
    this.descriptionEn,
    this.compareAtPrice,
    this.categoryId,
    this.categoryNameAr,
    this.categoryNameEn,
    this.imageUrl,
    this.imageFit = BoxFit.fill,
    this.imageAlignment = Alignment.center,
    this.prepMinutes,
    this.stockQuantity = 0,
    this.calories,
    this.allergens = const <String>[],
    this.isFeatured = false,
    this.isActive = true,
    this.isDraft = false,
    this.updatedAt,
    this.discountPercentage,
    this.discountStartsAt,
    this.discountEndsAt,
  });

  /// An empty product the admin fills in and saves for the first time.
  ///
  /// The id is a local key that never reaches the database: the repository
  /// creates the row and hands the saved product back.
  AdminProduct.draft(String localId)
    : id = localId,
      nameAr = '',
      nameEn = '',
      sku = '',
      slug = '',
      basePrice = 0,
      descriptionAr = null,
      descriptionEn = null,
      compareAtPrice = null,
      categoryId = null,
      categoryNameAr = null,
      categoryNameEn = null,
      imageUrl = null,
      imageFit = BoxFit.fill,
      imageAlignment = Alignment.center,
      prepMinutes = null,
      stockQuantity = 0,
      calories = null,
      allergens = const <String>[],
      isFeatured = false,
      isActive = true,
      isDraft = true,
      updatedAt = null,
      discountPercentage = null,
      discountStartsAt = null,
      discountEndsAt = null;

  final String id;
  final String nameAr;
  final String nameEn;
  final String sku;
  final String slug;
  final double basePrice;
  final String? descriptionAr;
  final String? descriptionEn;
  final double? compareAtPrice;
  final String? categoryId;
  final String? categoryNameAr;
  final String? categoryNameEn;
  final String? imageUrl;

  /// How the picture of the product fills its space.
  final BoxFit imageFit;

  /// Where the picture of the product sits in its space.
  final Alignment imageAlignment;
  final int? prepMinutes;

  /// Scheduled direct discount of the product, in percent (0..100).
  final double? discountPercentage;

  /// When the direct discount starts. Null means it is not scheduled.
  final DateTime? discountStartsAt;

  /// When the direct discount ends. Null means it does not expire.
  final DateTime? discountEndsAt;

  /// Units on hand for the branch the dashboard reviews.
  ///
  /// The stock itself lives in `inventory.branch_stock`; the card only needs
  /// the quantity of the branch it is edited in.
  final int stockQuantity;

  /// The nutrition value of the product, in calories.
  final int? calories;

  /// The allergens the product carries.
  final List<String> allergens;

  final bool isFeatured;
  final bool isActive;
  final DateTime? updatedAt;

  /// True while the product lives only in the dashboard.
  final bool isDraft;

  /// The product name in the language of the admin panel.
  ///
  /// A name that was left empty stays empty: the name of the other language
  /// never takes its place.
  String nameFor(AppLanguage language) {
    return language.isArabic ? nameAr : nameEn;
  }

  /// The category name in the language of the admin panel.
  String categoryNameFor(AppLanguage language) {
    return language.isArabic ? (categoryNameAr ?? '') : (categoryNameEn ?? '');
  }

  factory AdminProduct.fromRow(Map<String, dynamic> row, {int? stockQuantity}) {
    return AdminProduct(
      id: '${row['id'] ?? ''}',
      nameAr: '${row['name_ar'] ?? ''}',
      nameEn: '${row['name_en'] ?? ''}',
      sku: '${row['sku'] ?? ''}',
      slug: '${row['slug'] ?? ''}',
      basePrice: _toDouble(row['base_price']),
      descriptionAr: row['description_ar'] as String?,
      descriptionEn: row['description_en'] as String?,
      compareAtPrice: row['compare_at_price'] == null
          ? null
          : _toDouble(row['compare_at_price']),
      categoryId: row['category_id'] as String?,
      categoryNameAr: row['category_name_ar'] as String?,
      categoryNameEn: row['category_name_en'] as String?,
      imageUrl: row['image_url'] as String?,
      imageFit: fitFromName(row['image_fit'] as String?),
      imageAlignment: alignmentFromName(row['image_alignment'] as String?),
      prepMinutes: row['prep_minutes'] == null
          ? null
          : (row['prep_minutes'] as num).toInt(),
      discountPercentage: row['discount_percentage'] == null
          ? null
          : (row['discount_percentage'] as num).toDouble(),
      discountStartsAt: _toDateTime(row['discount_starts_at']),
      discountEndsAt: _toDateTime(row['discount_ends_at']),
      stockQuantity: stockQuantity ?? _toInt(row['stock_quantity']),
      calories: row['calories'] == null
          ? null
          : (row['calories'] as num).toInt(),
      allergens: _toStringList(row['allergens']),
      isFeatured: row['is_featured'] == true,
      isActive: row['is_active'] != false,
      updatedAt: _toDateTime(row['updated_at']),
    );
  }

  AdminProduct copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? sku,
    String? slug,
    double? basePrice,
    String? descriptionAr,
    bool clearDescriptionAr = false,
    String? descriptionEn,
    bool clearDescriptionEn = false,
    double? compareAtPrice,
    bool clearCompareAtPrice = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? categoryNameAr,
    bool clearCategoryNameAr = false,
    String? categoryNameEn,
    bool clearCategoryNameEn = false,
    String? imageUrl,
    bool clearImageUrl = false,
    BoxFit? imageFit,
    Alignment? imageAlignment,
    int? prepMinutes,
    bool clearPrepMinutes = false,
    int? calories,
    bool clearCalories = false,
    double? discountPercentage,
    bool clearDiscountPercentage = false,
    DateTime? discountStartsAt,
    bool clearDiscountStartsAt = false,
    DateTime? discountEndsAt,
    bool clearDiscountEndsAt = false,
    int? stockQuantity,
    List<String>? allergens,
    bool? isFeatured,
    bool? isActive,
    bool? isDraft,
    DateTime? updatedAt,
  }) {
    return AdminProduct(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      sku: sku ?? this.sku,
      slug: slug ?? this.slug,
      basePrice: basePrice ?? this.basePrice,
      descriptionAr: clearDescriptionAr
          ? null
          : (descriptionAr ?? this.descriptionAr),
      descriptionEn: clearDescriptionEn
          ? null
          : (descriptionEn ?? this.descriptionEn),
      compareAtPrice: clearCompareAtPrice
          ? null
          : (compareAtPrice ?? this.compareAtPrice),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryNameAr: clearCategoryNameAr
          ? null
          : (categoryNameAr ?? this.categoryNameAr),
      categoryNameEn: clearCategoryNameEn
          ? null
          : (categoryNameEn ?? this.categoryNameEn),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      imageFit: imageFit ?? this.imageFit,
      imageAlignment: imageAlignment ?? this.imageAlignment,
      prepMinutes: clearPrepMinutes ? null : (prepMinutes ?? this.prepMinutes),
      discountPercentage: clearDiscountPercentage
          ? null
          : (discountPercentage ?? this.discountPercentage),
      discountStartsAt: clearDiscountStartsAt
          ? null
          : (discountStartsAt ?? this.discountStartsAt),
      discountEndsAt: clearDiscountEndsAt
          ? null
          : (discountEndsAt ?? this.discountEndsAt),
      stockQuantity: stockQuantity ?? this.stockQuantity,
      calories: clearCalories ? null : (calories ?? this.calories),
      allergens: allergens ?? this.allergens,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      isDraft: isDraft ?? this.isDraft,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// The columns the dashboard writes back to `catalog.products`.
  Map<String, dynamic> toWriteRow() {
    return <String, dynamic>{
      'name_ar': nameAr.trim(),
      'name_en': nameEn.trim(),
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'base_price': basePrice,
      'compare_at_price': compareAtPrice,
      'category_id': categoryId,
      'image_url': imageUrl,
      'is_featured': isFeatured,
      'is_active': isActive,
      'prep_minutes': prepMinutes,
      'discount_percentage': discountPercentage,
      'discount_starts_at': discountStartsAt?.toIso8601String(),
      'discount_ends_at': discountEndsAt?.toIso8601String(),
      'calories': calories,
      'allergens': allergens,
    };
  }

  static List<String> _toStringList(Object? value) {
    if (value is List) {
      return value.map((entry) => '$entry').toList(growable: false);
    }
    return const <String>[];
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  /// Alias kept for callers that name the discount percentage differently.
  double? get discountPercent => discountPercentage;

  /// Alias kept for callers that name the discount percentage differently.
  double? get discountPct => discountPercentage;

  /// Alias kept for callers that name the start date differently.
  DateTime? get discountStartDate => discountStartsAt;

  /// Alias kept for callers that name the start date differently.
  DateTime? get discountStart => discountStartsAt;

  /// Alias kept for callers that name the end date differently.
  DateTime? get discountEndDate => discountEndsAt;

  /// Alias kept for callers that name the end date differently.
  DateTime? get discountEnd => discountEndsAt;

  /// Whether the product discount applies right now.
  ///
  /// The window is the one the server uses: a discount without a window is
  /// always on, a discount whose window has passed is off.
  bool isDiscountActiveAt(DateTime now) {
    final percentage = discountPercentage;
    if (percentage == null || percentage <= 0) return false;
    final start = discountStartsAt;
    if (start != null && now.isBefore(start)) return false;
    final end = discountEndsAt;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  /// The price the customer pays while the discount is on.
  ///
  /// Null when there is no discount, so a caller never shows a price that was
  /// not actually charged.
  double? priceAfterDiscountAt(DateTime now, {double? regularPrice}) {
    if (!isDiscountActiveAt(now)) return null;
    final regular = regularPrice ?? basePrice;
    final percentage = discountPercentage ?? 0;
    return double.parse((regular * (1 - percentage / 100)).toStringAsFixed(2));
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
