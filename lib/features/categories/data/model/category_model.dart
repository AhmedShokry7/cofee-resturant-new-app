import 'package:flutter/material.dart';
import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A product category.
///
/// The database stores [slug] and a stable id; the label is locale aware.
/// [icon] stays an [IconData] in the UI layer and is not persisted: the column
/// is `icon_key` and the mapping happens in the presentation layer.
class CategoryModel {
  const CategoryModel({
    String? label,
    required this.icon,
    this.id,
    this.slug,
    this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    this.iconKey,
    this.parentId,
    this.sortOrder = 0,
  }) : _legacyLabel = label ?? '';

  /// Stable id from `catalog.categories.id`. Null for legacy mock data.
  final String? id;

  /// Stable public identifier. Replaces matching categories by name string,
  /// which is what the old model forced the app to do.
  final String? slug;

  final String? parentId;
  final String? nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;

  /// Asset key from `catalog.categories.icon_key`, never an IconData.
  final String? iconKey;

  final int sortOrder;

  /// Kept as a field so the existing call sites are unchanged.
  final IconData icon;

  /// Holds the single-language label used by the old mock data, so
  /// `label` can stay a getter and still return something sensible before the
  /// bilingual columns are populated.
  final String _legacyLabel;

  bool get isArabic => AppLocale.instance.isArabic;

  String get label {
    final ar = nameAr ?? '';
    final en = nameEn ?? '';
    if (ar.trim().isEmpty && en.trim().isEmpty) return _legacyLabel;
    return pickText((ar: ar, en: en), isArabic: isArabic);
  }

  String get description => pickText((
    ar: descriptionAr ?? '',
    en: descriptionEn ?? '',
  ), isArabic: isArabic);

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final ar = Db.textOrNull(json['name_ar']) ?? '';
    final en = Db.textOrNull(json['name_en']) ?? '';
    return CategoryModel(
      id: Db.textOrNull(json['id']),
      slug: Db.textOrNull(json['slug']),
      parentId: Db.textOrNull(json['parent_id']),
      nameAr: ar.isEmpty ? null : ar,
      nameEn: en.isEmpty ? null : en,
      descriptionAr: Db.textOrNull(json['description_ar']),
      descriptionEn: Db.textOrNull(json['description_en']),
      imageUrl: Db.textOrNull(json['image_url']),
      iconKey: Db.textOrNull(json['icon_key']),
      sortOrder: Db.asInt(json['sort_order']),
      // IconData cannot come from the database. The UI resolves iconKey to an
      // asset; until a category declares one, fall back to a neutral glyph so
      // the grid never renders a broken icon.
      icon: resolveCategoryIcon(Db.textOrNull(json['icon_key'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'parent_id': parentId,
    'name_ar': nameAr,
    'name_en': nameEn,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'image_url': imageUrl,
    'icon_key': iconKey,
    'sort_order': sortOrder,
  };

  CategoryModel copyWith({
    String? id,
    String? slug,
    String? label,
    IconData? icon,
    String? nameAr,
    String? nameEn,
    String? iconKey,
  }) => CategoryModel(
    id: id ?? this.id,
    slug: slug ?? this.slug,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    iconKey: iconKey ?? this.iconKey,
    icon: icon ?? this.icon,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && (other.id ?? other.slug) == (id ?? slug);

  @override
  int get hashCode => Object.hash(id, slug);

  @override
  String toString() => 'CategoryModel($slug, $label)';
}

/// Maps a persisted `icon_key` to an icon.
///
/// Unknown keys resolve to a neutral placeholder rather than throwing, so a new
/// category added in the admin panel renders immediately instead of crashing.
IconData resolveCategoryIcon(String? key) {
  switch (key) {
    case 'hot_coffee':
      return Icons.local_cafe_outlined;
    case 'cold_coffee':
      return Icons.ac_unit;
    case 'tea':
      return Icons.emoji_food_beverage_outlined;
    case 'desserts':
      return Icons.icecream_outlined;
    case 'snacks':
      return Icons.fastfood_outlined;
    case 'milkshakes':
      return Icons.local_drink_outlined;
    case 'soft_drinks':
      return Icons.local_drink_outlined;
    case 'bakery':
      return Icons.bakery_dining_outlined;
    case 'donuts':
      return Icons.donut_small_outlined;
    case 'bundles':
      return Icons.inventory_2_outlined;
    default:
      return Icons.category_outlined;
  }
}
