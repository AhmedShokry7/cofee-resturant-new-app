import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A curated combo sold for one bundle price.
///
/// [components] replaces the bare `List<String> productIds` the model used to
/// carry: the database stores a quantity per component, which the old shape
/// could not express.
class BundleModel {
  const BundleModel({
    required this.id,
    String? title,
    String? subtitle,
    required this.productIds,
    required this.price,
    this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    this.components = const [],
    this.isActive = true,
    this.sortOrder = 0,
  }) : _legacyTitle = title ?? '',
       _legacySubtitle = subtitle ?? '';

  final String id;

  /// Bilingual pair from `catalog.bundles`.
  final String? nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;

  final bool isActive;
  final int sortOrder;

  /// Component product ids, kept for the existing call sites.
  final List<String> productIds;

  /// Component products with their quantity. Empty when the bundle was loaded
  /// without its items, which callers must treat as "not loaded", not "empty".
  final List<BundleComponent> components;

  final double price;

  /// Single-language values carried over from the mock data, so `title` and
  /// `subtitle` can stay locale-aware getters.
  final String _legacyTitle;
  final String _legacySubtitle;

  bool get isArabic => AppLocale.instance.isArabic;

  String get title {
    final ar = nameAr ?? '';
    final en = nameEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) return _legacyTitle;
    return pickText((ar: ar, en: en), isArabic: isArabic);
  }

  String get subtitle {
    final ar = descriptionAr ?? '';
    final en = descriptionEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) return _legacySubtitle;
    return pickText((ar: ar, en: en), isArabic: isArabic);
  }

  /// The image column, kept under its new name.
  String get image => imageUrl ?? '';

  /// Sum of the component base prices, for comparing against [price].
  double componentTotal(double Function(String productId) priceOf) {
    var total = 0.0;
    for (final c in components) {
      total += priceOf(c.productId) * c.quantity;
    }
    return total;
  }

  /// Null when the bundle has no components loaded.
  BundleModel copyWith({List<BundleComponent>? components, double? price}) =>
      BundleModel(
        id: id,
        title: title,
        subtitle: subtitle,
        productIds: productIds,
        price: price ?? this.price,
        nameAr: nameAr,
        nameEn: nameEn,
        descriptionAr: descriptionAr,
        descriptionEn: descriptionEn,
        imageUrl: imageUrl,
        components: components ?? this.components,
        isActive: isActive,
        sortOrder: sortOrder,
      );

  /// Reads `catalog.bundles`. Pass the matching components when they were
  /// loaded alongside.
  factory BundleModel.fromJson(
    Map<String, dynamic> json, {
    List<BundleComponent> components = const [],
  }) {
    final id = Db.text(json['id']);
    return BundleModel(
      id: id,
      title: Db.textOrNull(json['title']) ?? '',
      nameAr: Db.textOrNull(json['name_ar']),
      nameEn: Db.textOrNull(json['name_en']),
      subtitle: Db.textOrNull(json['subtitle']) ?? '',
      descriptionAr: Db.textOrNull(json['description_ar']),
      descriptionEn: Db.textOrNull(json['description_en']),
      imageUrl: Db.textOrNull(json['image_url']),
      price: Db.asDouble(json['bundle_price'] ?? json['price']),
      isActive: json['is_active'] != false,
      sortOrder: Db.asInt(json['sort_order']),
      components: components,
      productIds: components.map((c) => c.productId).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name_ar': nameAr,
    'name_en': nameEn,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'image_url': imageUrl,
    'bundle_price': price,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}

class BundleComponent {
  const BundleComponent({
    required this.productId,
    required this.quantity,
    this.allowOptions = false,
    this.nameAr,
    this.nameEn,
    this.imageUrl,
  });

  final String productId;

  /// The field the old model could not express.
  final int quantity;

  final bool allowOptions;
  final String? nameAr;
  final String? nameEn;
  final String? imageUrl;

  String get name {
    final localized = pickText((
      ar: nameAr ?? '',
      en: nameEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return localized.isEmpty ? productId : localized;
  }

  factory BundleComponent.fromJson(Map<String, dynamic> json) =>
      BundleComponent(
        productId: Db.text(json['product_id']),
        quantity: Db.asInt(json['quantity'], fallback: 1),
        allowOptions: json['allow_options'] == true,
        nameAr: Db.textOrNull(json['name_ar']),
        nameEn: Db.textOrNull(json['name_en']),
        imageUrl: Db.textOrNull(json['image_url']),
      );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
    'allow_options': allowOptions,
    'name_ar': nameAr,
    'name_en': nameEn,
    'image_url': imageUrl,
  };
}
