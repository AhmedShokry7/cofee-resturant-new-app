import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// What a banner sends the customer to.
///
/// The database stores this as a short text code, so the codes live here once
/// instead of being compared as string literals all over the UI.
enum BannerTarget {
  category('category'),
  product('product'),
  bundle('bundle'),
  url('url'),
  none('none');

  const BannerTarget(this.storage);

  /// The value stored in `banners.target_type`.
  final String storage;

  /// Anything the app does not know is treated as 'none': a banner then shows
  /// itself but its button does nothing, which is what an unknown target did
  /// when the type was a raw string.
  static BannerTarget fromStorage(String value) => values.firstWhere(
    (target) => target.storage == value,
    orElse: () => BannerTarget.none,
  );
}

/// A home page banner.
///
/// [target] and [targetId] replace the raw English `targetCategory` string
/// the model used to carry. The database stores a typed reference, so renaming
/// a category can no longer silently break a banner.
class BannerModel {
  const BannerModel({
    required this.id,
    required this.image,
    String? title,
    String? subtitle,
    String? description,
    String? ctaLabel,
    String? targetCategory,
    this.titleAr,
    this.titleEn,
    this.subtitleAr,
    this.subtitleEn,
    this.descriptionAr,
    this.descriptionEn,
    this.ctaLabelAr,
    this.ctaLabelEn,
    this.targetCategoryAr,
    this.targetCategoryEn,
    this.target = BannerTarget.category,
    this.targetId,
    this.targetUrl,
    this.sortOrder = 0,
    this.isPublished = false,
    this.startsAt,
    this.endsAt,
    this.targetProduct,
    this.targetBundle,
  }) : _legacyTitle = title ?? '',
       _legacySubtitle = subtitle ?? '',
       _legacyDescription = description ?? '',
       _legacyCtaLabel = ctaLabel ?? '',
       _legacyTargetCategory = targetCategory ?? '';

  final String id;

  final String? titleAr;
  final String? titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? ctaLabelAr;
  final String? ctaLabelEn;
  final String? targetCategoryAr;
  final String? targetCategoryEn;

  /// Where the banner's button takes the customer.
  final BannerTarget target;
  final String? targetId;
  final String? targetUrl;

  final int sortOrder;
  final bool isPublished;
  final DateTime? startsAt;
  final DateTime? endsAt;

  final String image;

  /// Resolved when [target] is [BannerTarget.product]. Populated by the
  /// repository after loading banners.
  final ProductModel? targetProduct;

  /// Resolved when [target] is [BannerTarget.bundle]. Populated by the
  /// repository after loading banners.
  final BundleModel? targetBundle;

  /// Single-language values from the mock data, so the locale-aware getters stay
  /// safe while the bilingual columns are empty.
  final String _legacyTitle;
  final String _legacySubtitle;
  final String _legacyDescription;
  final String _legacyCtaLabel;
  final String _legacyTargetCategory;

  /// Kept so the existing banner detail screen keeps working.
  String get targetCategory =>
      _pick(targetCategoryAr, targetCategoryEn, _legacyTargetCategory);

  bool get isArabic => AppLocale.instance.isArabic;

  String get title => _pick(titleAr, titleEn, _legacyTitle);
  String get subtitle => _pick(subtitleAr, subtitleEn, _legacySubtitle);
  String get description =>
      _pick(descriptionAr, descriptionEn, _legacyDescription);
  String get ctaLabel => _pick(ctaLabelAr, ctaLabelEn, _legacyCtaLabel);

  String _pick(String? ar, String? en, String legacy) {
    final a = ar ?? '';
    final b = en ?? '';
    if (a.trim().isEmpty && b.trim().isEmpty) return legacy;
    return pickText((ar: a, en: b), isArabic: isArabic);
  }

  BannerModel copyWith({
    String? id,
    String? image,
    String? title,
    String? subtitle,
    String? description,
    String? ctaLabel,
    String? targetCategory,
    String? titleAr,
    String? titleEn,
    String? subtitleAr,
    String? subtitleEn,
    String? descriptionAr,
    String? descriptionEn,
    String? ctaLabelAr,
    String? ctaLabelEn,
    String? targetCategoryAr,
    String? targetCategoryEn,
    BannerTarget? target,
    String? targetId,
    String? targetUrl,
    int? sortOrder,
    bool? isPublished,
    DateTime? startsAt,
    DateTime? endsAt,
    ProductModel? targetProduct,
    BundleModel? targetBundle,
  }) => BannerModel(
    id: id ?? this.id,
    image: image ?? this.image,
    title: title ?? _legacyTitle,
    subtitle: subtitle ?? _legacySubtitle,
    description: description ?? _legacyDescription,
    ctaLabel: ctaLabel ?? _legacyCtaLabel,
    targetCategory: targetCategory ?? _legacyTargetCategory,
    titleAr: titleAr ?? this.titleAr,
    titleEn: titleEn ?? this.titleEn,
    subtitleAr: subtitleAr ?? this.subtitleAr,
    subtitleEn: subtitleEn ?? this.subtitleEn,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    ctaLabelAr: ctaLabelAr ?? this.ctaLabelAr,
    ctaLabelEn: ctaLabelEn ?? this.ctaLabelEn,
    targetCategoryAr: targetCategoryAr ?? this.targetCategoryAr,
    targetCategoryEn: targetCategoryEn ?? this.targetCategoryEn,
    target: target ?? this.target,
    targetId: targetId ?? this.targetId,
    targetUrl: targetUrl ?? this.targetUrl,
    sortOrder: sortOrder ?? this.sortOrder,
    isPublished: isPublished ?? this.isPublished,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    targetProduct: targetProduct ?? this.targetProduct,
    targetBundle: targetBundle ?? this.targetBundle,
  );

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
    id: Db.text(json['id']),
    title: Db.textOrNull(json['title']) ?? '',
    titleAr: Db.textOrNull(json['title_ar']),
    titleEn: Db.textOrNull(json['title_en']),
    subtitle: Db.textOrNull(json['subtitle']) ?? '',
    subtitleAr: Db.textOrNull(json['subtitle_ar']),
    subtitleEn: Db.textOrNull(json['subtitle_en']),
    description: Db.textOrNull(json['description']) ?? '',
    descriptionAr: Db.textOrNull(json['description_ar']),
    descriptionEn: Db.textOrNull(json['description_en']),
    ctaLabel: Db.textOrNull(json['cta_label']) ?? '',
    ctaLabelAr: Db.textOrNull(json['cta_label_ar']),
    ctaLabelEn: Db.textOrNull(json['cta_label_en']),
    targetCategoryAr: Db.textOrNull(json['target_category_name_ar']),
    targetCategoryEn: Db.textOrNull(json['target_category_name_en']),
    image: Db.textOrNull(json['image_url']) ?? '',
    target: BannerTarget.fromStorage(Db.text(json['target_type'], 'category')),
    targetId: Db.textOrNull(json['target_id']),
    targetUrl: Db.textOrNull(json['target_url']),
    sortOrder: Db.asInt(json['sort_order']),
    isPublished: json['is_published'] != false,
    startsAt: _date(json['starts_at']),
    endsAt: _date(json['ends_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title_ar': titleAr,
    'title_en': titleEn,
    'subtitle_ar': subtitleAr,
    'subtitle_en': subtitleEn,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'cta_label_ar': ctaLabelAr,
    'cta_label_en': ctaLabelEn,
    'image_url': image,
    'target_type': target.storage,
    'target_id': targetId,
    'target_url': targetUrl,
    'sort_order': sortOrder,
    'is_published': isPublished,
  };

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
