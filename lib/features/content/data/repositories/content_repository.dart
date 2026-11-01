import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/content/data/model/faq_model.dart';
import 'package:new_coffee/features/content/data/model/legal_document_model.dart';
import 'package:new_coffee/features/on_boarding/data/model/on_boarding_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    final rows =
        await client
                .from('faq_items')
                .select(
                  'question_ar, question_en, answer_ar, answer_en, sort_order',
                )
                .eq('is_active', true)
                .order('sort_order')
            as List;
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
    final client = _client;
    if (client == null) {
      throw StateError('Onboarding slides need a configured Supabase backend.');
    }

    final rows =
        await client
                .from('onboarding_slides')
                .select(
                  'image_url, title_ar, title_en, body_ar, body_en, sort_order',
                )
                .eq('is_active', true)
                .order('sort_order')
            as List;
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) OnBoardingModel.fromDatabase(row),
    ];
  }

  @override
  Future<LegalDocumentModel?> legalDocument(String slug) async {
    final client = _client;
    if (client == null || slug.isEmpty) return null;

    final rows =
        await client
                .from('legal_documents')
                .select()
                .eq('slug', slug)
                .eq('is_published', true)
                .limit(1)
            as List;
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) return null;
    return LegalDocumentModel.fromDatabase(rows.first as Map<String, dynamic>);
  }

  @override
  Future<double> deliveryFee() async {
    final client = _client;
    if (client == null) {
      throw StateError('Delivery fee needs a configured Supabase backend.');
    }

    final rows =
        await client
                .from('delivery_zones')
                .select('delivery_fee')
                .eq('is_active', true)
                .order('delivery_fee')
                .limit(1)
            as List;
    if (rows.isEmpty || rows.first is! Map<String, dynamic>) {
      throw StateError('No active delivery zone.');
    }
    return Db.asDouble((rows.first as Map<String, dynamic>)['delivery_fee']);
  }
}
