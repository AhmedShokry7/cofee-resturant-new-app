import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/coupons/domain/entities/coupon_json.dart';

class AdminCouponCategoryTarget {
  const AdminCouponCategoryTarget({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.imageUrl,
    this.isActive = true,
    this.productsCount = 0,
  });

  final String id;
  final String? nameAr;
  final String? nameEn;
  final String? imageUrl;
  final bool isActive;
  final int productsCount;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    return fallback != null && fallback.isNotEmpty ? fallback : id;
  }

  String get searchText => [nameAr ?? '', nameEn ?? ''].join(' ').toLowerCase();

  factory AdminCouponCategoryTarget.fromJson(Map<String, dynamic> json) =>
      AdminCouponCategoryTarget(
        id: '${json['id'] ?? ''}',
        nameAr: json['name_ar'] as String?,
        nameEn: json['name_en'] as String?,
        imageUrl: json['image_url'] as String?,
        isActive: json['is_active'] == true,
        productsCount: couponInt(json['products_count']),
      );
}

class AdminCouponProductTarget {
  const AdminCouponProductTarget({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.sku,
    this.imageUrl,
    this.basePrice = 0,
    this.isActive = true,
    this.isArchived = false,
    this.categoryId,
    this.categoryNameAr,
    this.categoryNameEn,
  });

  final String id;
  final String? nameAr;
  final String? nameEn;
  final String? sku;
  final String? imageUrl;
  final double basePrice;
  final bool isActive;
  final bool isArchived;
  final String? categoryId;
  final String? categoryNameAr;
  final String? categoryNameEn;

  bool get isSelectable => !isArchived;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return sku?.trim() ?? id;
  }

  String? categoryNameFor(AppLanguage language) {
    final name = language.isArabic
        ? categoryNameAr?.trim()
        : categoryNameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic
        ? categoryNameEn?.trim()
        : categoryNameAr?.trim();
    return fallback != null && fallback.isNotEmpty ? fallback : null;
  }

  String get searchText => [
    nameAr ?? '',
    nameEn ?? '',
    sku ?? '',
    categoryNameAr ?? '',
    categoryNameEn ?? '',
  ].join(' ').toLowerCase();

  factory AdminCouponProductTarget.fromJson(Map<String, dynamic> json) =>
      AdminCouponProductTarget(
        id: '${json['id'] ?? ''}',
        nameAr: json['name_ar'] as String?,
        nameEn: json['name_en'] as String?,
        sku: json['sku'] as String?,
        imageUrl: json['image_url'] as String?,
        basePrice: couponDouble(json['base_price']),
        isActive: json['is_active'] == true,
        isArchived: json['is_archived'] == true,
        categoryId: json['category_id'] as String?,
        categoryNameAr: json['category_name_ar'] as String?,
        categoryNameEn: json['category_name_en'] as String?,
      );
}

/// The categories and products a coupon can be scoped to.
class AdminCouponTargets {
  const AdminCouponTargets({
    this.categories = const <AdminCouponCategoryTarget>[],
    this.products = const <AdminCouponProductTarget>[],
  });

  final List<AdminCouponCategoryTarget> categories;
  final List<AdminCouponProductTarget> products;

  static const empty = AdminCouponTargets();

  bool get isEmpty => categories.isEmpty && products.isEmpty;

  AdminCouponProductTarget? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  AdminCouponCategoryTarget? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  factory AdminCouponTargets.fromJson(Map<String, dynamic> json) =>
      AdminCouponTargets(
        categories: _map(
          json['categories'],
          AdminCouponCategoryTarget.fromJson,
        ),
        products: _map(json['products'], AdminCouponProductTarget.fromJson),
      );

  static List<T> _map<T>(
    Object? value,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (value is! List) return <T>[];
    return value
        .whereType<Map>()
        .map((row) => fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
