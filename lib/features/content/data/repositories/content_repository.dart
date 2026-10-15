import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:new_coffee/features/profile/data/model/faq_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  })  : _legacyTitle = title ?? '',
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
    final text = pickText(
      (ar: titleAr ?? '', en: titleEn ?? ''),
      isArabic: AppLocale.instance.isArabic,
    );
    return text.isEmpty ? _legacyTitle : text;
  }

  String get content {
    final text = pickText(
      (ar: contentAr ?? '', en: contentEn ?? ''),
      isArabic: AppLocale.instance.isArabic,
    );
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

abstract class ContentRepository {
  Future<List<FaqModel>> faqs();
  Future<List<OnBoardingModel>> onBoardingSlides();
  Future<LegalDocumentModel?> legalDocument(String slug);
  Future<double> deliveryFee();
}

class SupabaseContentRepository implements ContentRepository {
  SupabaseContentRepository({SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  @override
  Future<List<FaqModel>> faqs() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('faq_items')
        .select('question_ar, question_en, answer_ar, answer_en, sort_order')
        .eq('is_active', true)
        .order('sort_order') as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          FaqModel(
            questionAr: Db.textOrNull(row['question_ar']),
            questionEn: Db.textOrNull(row['question_en']),
            answerAr: Db.textOrNull(row['answer_ar']),
            answerEn: Db.textOrNull(row['answer_en']),
          ),
    ];
  }

  @override
  Future<List<OnBoardingModel>> onBoardingSlides() async {
    // Return hardcoded slides - no database dependency
    return [
      OnBoardingModel(
        title: 'مرحباً بك في تطبيق القهوة',
        body: 'اكتشف أفضل المشروبات والمناسبات المميزة',
        image: AppImages.onBoarding1,
      ),
      OnBoardingModel(
        title: 'اختر مشروبك المفضل',
        body: 'تصفح القائمة وتمتع بعروض حصرية',
        image: AppImages.onBoarding2,
      ),
      OnBoardingModel(
        title: 'قم بالطلب بكل سهولة',
        body: 'اختصر الخطوات وادفع عند الاستلام',
        image: AppImages.onBoarding3,
      ),
    ];
  }

  @override
  Future<LegalDocumentModel?> legalDocument(String slug) async {
    final client = _client;
    if (client == null || slug.isEmpty) return null;

    final rows = await client
        .from('legal_documents')
        .select()
        .eq('slug', slug)
        .eq('is_published', true)
        .limit(1) as List;
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) return null;
    return LegalDocumentModel.fromDatabase(rows.first as Map<String, dynamic>);
  }

  @override
  Future<double> deliveryFee() async {
    final client = _client;
    if (client == null) return 0;

    try {
      final rows = await client
          .from('delivery_zones')
          .select('delivery_fee')
          .eq('is_active', true)
          .order('delivery_fee')
          .limit(1) as List;
      if (rows.isEmpty || rows.first is! Map<String, dynamic>) return 0;
      return Db.asDouble(
        (rows.first as Map<String, dynamic>)['delivery_fee'],
      );
    } catch (_) {
      return 0;
    }
  }
}