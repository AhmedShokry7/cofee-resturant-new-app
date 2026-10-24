import 'package:admin_app/core/locale/app_locale.dart';

/// A category the admin can put a product in.
class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.isActive = true,
    this.imageUrl,
    this.productCount = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final bool isActive;
  final String? imageUrl;
  final int productCount;

  /// The category name in the language of the admin panel.
  ///
  /// A name that was left empty stays empty.
  String nameFor(AppLanguage language) {
    return language.isArabic ? nameAr : nameEn;
  }

  AdminCategory copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    bool clearDescriptionAr = false,
    String? descriptionEn,
    bool clearDescriptionEn = false,
    bool? isActive,
    String? imageUrl,
    bool clearImageUrl = false,
    int? productCount,
  }) {
    return AdminCategory(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      descriptionAr: clearDescriptionAr
          ? null
          : (descriptionAr ?? this.descriptionAr),
      descriptionEn: clearDescriptionEn
          ? null
          : (descriptionEn ?? this.descriptionEn),
      isActive: isActive ?? this.isActive,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      productCount: productCount ?? this.productCount,
    );
  }

  factory AdminCategory.fromRow(Map<String, dynamic> row) {
    return AdminCategory(
      id: '${row['id'] ?? ''}',
      nameAr: '${row['name_ar'] ?? ''}',
      nameEn: '${row['name_en'] ?? ''}',
      descriptionAr: row['description_ar'] as String?,
      descriptionEn: row['description_en'] as String?,
      isActive: row['is_active'] != false,
      imageUrl: row['image_url'] as String?,
      productCount: (row['product_count'] as num?)?.toInt() ?? 0,
    );
  }
}
