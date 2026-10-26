import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/reviews/data/models/review_json.dart';

/// The product a review belongs to, with the category it is sold under.
class AdminReviewProduct {
  const AdminReviewProduct({
    required this.id,
    this.nameAr,
    this.nameEn,
    this.sku,
    this.imageUrl,
    this.categoryNameAr,
    this.categoryNameEn,
  });

  final String id;
  final String? nameAr;
  final String? nameEn;
  final String? sku;
  final String? imageUrl;
  final String? categoryNameAr;
  final String? categoryNameEn;

  String nameFor(AppLanguage language) =>
      _localized(nameAr, nameEn, language) ?? sku ?? id;

  String? categoryFor(AppLanguage language) =>
      _localized(categoryNameAr, categoryNameEn, language);

  factory AdminReviewProduct.fromJson(Map<String, dynamic> json) =>
      AdminReviewProduct(
        id: '${json['id'] ?? ''}',
        nameAr: reviewText(json['name_ar']),
        nameEn: reviewText(json['name_en']),
        sku: reviewText(json['sku']),
        imageUrl: reviewText(json['image_url']),
        categoryNameAr: reviewText(json['category_name_ar']),
        categoryNameEn: reviewText(json['category_name_en']),
      );
}

/// The customer who wrote a review.
class AdminReviewCustomer {
  const AdminReviewCustomer({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  factory AdminReviewCustomer.fromJson(Map<String, dynamic> json) =>
      AdminReviewCustomer(
        id: '${json['id'] ?? ''}',
        fullName: reviewText(json['full_name']),
        email: reviewText(json['email']),
        phone: reviewText(json['phone']),
        avatarUrl: reviewText(json['avatar_url']),
      );
}

class AdminReview {
  const AdminReview({
    required this.id,
    required this.rating,
    required this.product,
    required this.customer,
    this.titleAr,
    this.titleEn,
    this.bodyAr,
    this.bodyEn,
    this.isPublished = true,
    this.orderId,
    this.orderNumber,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int rating;
  final AdminReviewProduct product;
  final AdminReviewCustomer customer;
  final String? titleAr;
  final String? titleEn;
  final String? bodyAr;
  final String? bodyEn;
  final bool isPublished;
  final String? orderId;
  final String? orderNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isVerifiedPurchase => orderId != null;
  bool get isLowRating => rating <= 2;

  String? titleFor(AppLanguage language) =>
      _localized(titleAr, titleEn, language);

  String? bodyFor(AppLanguage language) => _localized(bodyAr, bodyEn, language);

  factory AdminReview.fromJson(Map<String, dynamic> json) {
    final product = reviewMap(json['product']);
    final customer = reviewMap(json['customer']);
    final rating = reviewInt(json['rating']);
    return AdminReview(
      id: '${json['id'] ?? ''}',
      rating: rating.clamp(1, 5),
      product: product == null
          ? const AdminReviewProduct(id: '')
          : AdminReviewProduct.fromJson(product),
      customer: customer == null
          ? const AdminReviewCustomer(id: '')
          : AdminReviewCustomer.fromJson(customer),
      titleAr: reviewText(json['title_ar']),
      titleEn: reviewText(json['title_en']),
      bodyAr: reviewText(json['body_ar']),
      bodyEn: reviewText(json['body_en']),
      isPublished: json['is_published'] == true,
      orderId: reviewText(json['order_id']),
      orderNumber: reviewText(json['order_number']),
      createdAt: reviewDate(json['created_at']),
      updatedAt: reviewDate(json['updated_at']),
    );
  }
}

String? _localized(String? arabic, String? english, AppLanguage language) {
  final preferred = language.isArabic ? arabic : english;
  if (preferred != null && preferred.isNotEmpty) return preferred;
  final fallback = language.isArabic ? english : arabic;
  return fallback != null && fallback.isNotEmpty ? fallback : null;
}
