import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A home page banner.
///
/// [targetType] and [targetId] replace the raw English `targetCategory` string
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
    this.targetType = 'category',
    this.targetId,
    this.targetUrl,
    this.sortOrder = 0,
    this.isPublished = false,
    this.startsAt,
    this.endsAt,
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

  /// 'category' | 'product' | 'bundle' | 'url' | 'none'
  final String targetType;
  final String? targetId;
  final String? targetUrl;

  final int sortOrder;
  final bool isPublished;
  final DateTime? startsAt;
  final DateTime? endsAt;

  final String image;

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
    targetType: Db.text(json['target_type'], 'category'),
    targetId: Db.textOrNull(json['target_id']),
    targetUrl: Db.textOrNull(json['target_url']),
    // Joined from catalog.categories when the row carries it.
    targetCategory: Db.textOrNull(json['target_category_name']) ?? '',
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
    'target_type': targetType,
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
