import 'package:admin_app/core/locale/app_locale.dart';

/// A bundle component: a product with its quantity inside a bundle.
class AdminBundleComponent {
  const AdminBundleComponent({
    required this.productId,
    required this.quantity,
    this.allowOptions = false,
    this.nameAr,
    this.nameEn,
    this.categoryNameAr,
    this.categoryNameEn,
    this.imageUrl,
    this.basePrice = 0,
  });

  final String productId;
  final int quantity;
  final bool allowOptions;
  final String? nameAr;
  final String? nameEn;
  final String? categoryNameAr;
  final String? categoryNameEn;
  final String? imageUrl;
  final double basePrice;

  String nameFor(AppLanguage language) {
    if (language.isArabic && nameAr != null && nameAr!.trim().isNotEmpty) {
      return nameAr!.trim();
    }
    if (!language.isArabic && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    return productId;
  }

  String categoryNameFor(AppLanguage language) {
    if (language.isArabic) return categoryNameAr?.trim() ?? '';
    return categoryNameEn?.trim() ?? '';
  }

  AdminBundleComponent copyWith({
    String? productId,
    int? quantity,
    bool? allowOptions,
    String? nameAr,
    String? nameEn,
    String? categoryNameAr,
    String? categoryNameEn,
    String? imageUrl,
    double? basePrice,
  }) {
    return AdminBundleComponent(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      allowOptions: allowOptions ?? this.allowOptions,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      categoryNameAr: categoryNameAr ?? this.categoryNameAr,
      categoryNameEn: categoryNameEn ?? this.categoryNameEn,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
    );
  }

  factory AdminBundleComponent.fromJson(Map<String, dynamic> json) {
    return AdminBundleComponent(
      productId: '${json['product_id'] ?? ''}',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      allowOptions: json['allow_options'] == true,
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      categoryNameAr: json['category_name_ar'] as String?,
      categoryNameEn: json['category_name_en'] as String?,
      imageUrl: json['image_url'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'allow_options': allowOptions,
  };
}

/// A bundle (combo) sold for one price.
class AdminBundle {
  const AdminBundle({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    this.bundlePrice,
    this.isActive = true,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
    this.components = const <AdminBundleComponent>[],
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;
  final double? bundlePrice;
  final bool isActive;
  final int sortOrder;
  final String? startsAt;
  final String? endsAt;
  final List<AdminBundleComponent> components;

  String nameFor(AppLanguage language) {
    return language.isArabic ? nameAr : nameEn;
  }

  double get effectivePrice {
    if (bundlePrice != null && bundlePrice! > 0) return bundlePrice!;
    return components.fold<double>(
      0,
      (sum, c) => sum + c.basePrice * c.quantity,
    );
  }

  AdminBundle copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    bool clearDescriptionAr = false,
    String? descriptionEn,
    bool clearDescriptionEn = false,
    String? imageUrl,
    bool clearImageUrl = false,
    double? bundlePrice,
    bool clearBundlePrice = false,
    bool? isActive,
    int? sortOrder,
    String? startsAt,
    bool clearStartsAt = false,
    String? endsAt,
    bool clearEndsAt = false,
    List<AdminBundleComponent>? components,
  }) {
    return AdminBundle(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      descriptionAr: clearDescriptionAr
          ? null
          : (descriptionAr ?? this.descriptionAr),
      descriptionEn: clearDescriptionEn
          ? null
          : (descriptionEn ?? this.descriptionEn),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      bundlePrice: clearBundlePrice ? null : (bundlePrice ?? this.bundlePrice),
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      components: components ?? this.components,
    );
  }

  factory AdminBundle.fromJson(Map<String, dynamic> json) {
    final componentsRaw = json['components'] as List<dynamic>?;
    final components =
        componentsRaw?.map((e) {
          if (e is AdminBundleComponent) return e;
          return AdminBundleComponent.fromJson(
            Map<String, dynamic>.from(e as Map),
          );
        }).toList() ??
        const <AdminBundleComponent>[];

    return AdminBundle(
      id: '${json['id'] ?? ''}',
      nameAr: '${json['name_ar'] ?? ''}',
      nameEn: '${json['name_en'] ?? ''}',
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      imageUrl: json['image_url'] as String?,
      bundlePrice: (json['bundle_price'] as num?)?.toDouble(),
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      components: components,
    );
  }

  Map<String, dynamic> toJson() => {
    'name_ar': nameAr,
    'name_en': nameEn,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'image_url': imageUrl,
    'bundle_price': bundlePrice,
    'is_active': isActive,
    'sort_order': sortOrder,
    'starts_at': startsAt,
    'ends_at': endsAt,
  };
}
