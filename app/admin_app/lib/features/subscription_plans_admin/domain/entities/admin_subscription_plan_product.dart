import 'package:admin_app/core/locale/app_locale.dart';

/// A catalog product that can be included in a subscription plan.
class AdminSubscriptionPlanProduct {
  const AdminSubscriptionPlanProduct({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.sku = '',
    this.imageUrl,
    this.basePrice = 0,
    this.isActive = true,
    this.categoryNameAr,
    this.categoryNameEn,
  });

  final String id;
  final String? nameAr;
  final String? nameEn;
  final String sku;
  final String? imageUrl;
  final double basePrice;
  final bool isActive;
  final String? categoryNameAr;
  final String? categoryNameEn;

  String nameFor(AppLanguage language) {
    final name = language.isArabic ? nameAr?.trim() : nameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic ? nameEn?.trim() : nameAr?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final code = sku.trim();
    return code.isEmpty ? id : code;
  }

  String categoryNameFor(AppLanguage language) {
    final name = language.isArabic
        ? categoryNameAr?.trim()
        : categoryNameEn?.trim();
    if (name != null && name.isNotEmpty) return name;
    final fallback = language.isArabic
        ? categoryNameEn?.trim()
        : categoryNameAr?.trim();
    return fallback ?? '';
  }

  factory AdminSubscriptionPlanProduct.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionPlanProduct(
      id: '${json['id'] ?? ''}',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      sku: '${json['sku'] ?? ''}',
      imageUrl: json['image_url'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] != false,
      categoryNameAr: json['category_name_ar'] as String?,
      categoryNameEn: json['category_name_en'] as String?,
    );
  }
}
