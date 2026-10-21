/// A product as the admin dashboard shows it.
///
/// The model mirrors the `catalog.products` table together with the images and
/// the options that belong to it. It is filled from the database later; until
/// then the page renders it from a sample so the card can be reviewed.
class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.sku,
    required this.slug,
    required this.basePrice,
    this.compareAtPrice,
    this.categoryNameAr,
    this.categoryNameEn,
    this.imageUrl,
    this.prepMinutes,
    this.isFeatured = false,
    this.isActive = true,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String sku;
  final String slug;
  final double basePrice;
  final double? compareAtPrice;
  final String? categoryNameAr;
  final String? categoryNameEn;
  final String? imageUrl;
  final int? prepMinutes;
  final bool isFeatured;
  final bool isActive;

  String get name => nameAr;

  String get categoryName {
    final ar = (categoryNameAr ?? '').trim();
    final en = (categoryNameEn ?? '').trim();
    return ar.isNotEmpty ? ar : en;
  }
}
