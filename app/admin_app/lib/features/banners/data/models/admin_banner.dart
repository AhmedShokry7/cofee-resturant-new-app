import 'package:admin_app/core/locale/app_locale.dart';

class AdminBanner {
  const AdminBanner({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    this.subtitleAr,
    this.subtitleEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.imageUrl,
    this.ctaLabelAr,
    this.ctaLabelEn,
    required this.targetType,
    this.targetId,
    this.targetUrl,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
    this.isPublished = true,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String imageUrl;
  final String? ctaLabelAr;
  final String? ctaLabelEn;
  final String targetType;
  final String? targetId;
  final String? targetUrl;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isPublished;

  String titleFor(AppLanguage language) =>
      language.isArabic ? titleAr : titleEn;

  factory AdminBanner.fromJson(Map<String, dynamic> json) {
    return AdminBanner(
      id: '${json['id'] ?? ''}',
      titleAr: '${json['title_ar'] ?? ''}',
      titleEn: '${json['title_en'] ?? ''}',
      subtitleAr: json['subtitle_ar'] as String?,
      subtitleEn: json['subtitle_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      imageUrl: '${json['image_url'] ?? ''}',
      ctaLabelAr: json['cta_label_ar'] as String?,
      ctaLabelEn: json['cta_label_en'] as String?,
      targetType: '${json['target_type'] ?? 'none'}',
      targetId: json['target_id'] as String?,
      targetUrl: json['target_url'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      startsAt: _toDateTime(json['starts_at']),
      endsAt: _toDateTime(json['ends_at']),
      isPublished: json['is_published'] != false,
    );
  }

  AdminBanner copyWith({
    String? titleAr,
    String? titleEn,
    String? subtitleAr,
    bool clearSubtitleAr = false,
    String? subtitleEn,
    bool clearSubtitleEn = false,
    String? descriptionAr,
    bool clearDescriptionAr = false,
    String? descriptionEn,
    bool clearDescriptionEn = false,
    String? imageUrl,
    String? ctaLabelAr,
    bool clearCtaLabelAr = false,
    String? ctaLabelEn,
    bool clearCtaLabelEn = false,
    String? targetType,
    String? targetId,
    bool clearTargetId = false,
    String? targetUrl,
    bool clearTargetUrl = false,
    int? sortOrder,
    DateTime? startsAt,
    bool clearStartsAt = false,
    DateTime? endsAt,
    bool clearEndsAt = false,
    bool? isPublished,
  }) {
    return AdminBanner(
      id: id,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      subtitleAr: clearSubtitleAr ? null : (subtitleAr ?? this.subtitleAr),
      subtitleEn: clearSubtitleEn ? null : (subtitleEn ?? this.subtitleEn),
      descriptionAr: clearDescriptionAr
          ? null
          : (descriptionAr ?? this.descriptionAr),
      descriptionEn: clearDescriptionEn
          ? null
          : (descriptionEn ?? this.descriptionEn),
      imageUrl: imageUrl ?? this.imageUrl,
      ctaLabelAr: clearCtaLabelAr ? null : (ctaLabelAr ?? this.ctaLabelAr),
      ctaLabelEn: clearCtaLabelEn ? null : (ctaLabelEn ?? this.ctaLabelEn),
      targetType: targetType ?? this.targetType,
      targetId: clearTargetId ? null : (targetId ?? this.targetId),
      targetUrl: clearTargetUrl ? null : (targetUrl ?? this.targetUrl),
      sortOrder: sortOrder ?? this.sortOrder,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      isPublished: isPublished ?? this.isPublished,
    );
  }

  Map<String, dynamic> toJson() => {
    'title_ar': titleAr,
    'title_en': titleEn,
    'subtitle_ar': subtitleAr,
    'subtitle_en': subtitleEn,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'image_url': imageUrl,
    'cta_label_ar': ctaLabelAr,
    'cta_label_en': ctaLabelEn,
    'target_type': targetType,
    'target_id': targetId,
    'target_url': targetUrl,
    'sort_order': sortOrder,
    'starts_at': startsAt?.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'is_published': isPublished,
  };

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
