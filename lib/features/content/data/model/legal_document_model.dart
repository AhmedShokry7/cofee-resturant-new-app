import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';

/// A published legal text (privacy policy, terms) as the CMS stores it.
class LegalDocumentModel {
  const LegalDocumentModel({
    required this.id,
    required this.slug,
    String? title,
    String? content,
    this.titleAr,
    this.titleEn,
    this.contentAr,
    this.contentEn,
    this.version,
    this.isPublished = true,
  }) : _legacyTitle = title ?? '',
       _legacyContent = content ?? '';

  final String id;
  final String slug;
  final String? titleAr;
  final String? titleEn;
  final String? contentAr;
  final String? contentEn;
  final String? version;
  final bool isPublished;

  final String _legacyTitle;
  final String _legacyContent;

  String get title {
    final text = pickText((
      ar: titleAr ?? '',
      en: titleEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyTitle : text;
  }

  String get content {
    final text = pickText((
      ar: contentAr ?? '',
      en: contentEn ?? '',
    ), isArabic: AppLocale.instance.isArabic);
    return text.isEmpty ? _legacyContent : text;
  }

  factory LegalDocumentModel.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    return LegalDocumentModel(
      id: Db.text(map['id']),
      slug: Db.text(map['slug']),
      titleAr: Db.textOrNull(map['title_ar']),
      titleEn: Db.textOrNull(map['title_en']),
      contentAr: Db.textOrNull(map['content_ar']),
      contentEn: Db.textOrNull(map['content_en']),
      version: Db.textOrNull(map['version']),
      isPublished: Db.asBool(map['is_published'], fallback: true),
    );
  }
}
