import 'package:admin_app/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only RPC boundary for assistant configuration and shop knowledge.
/// Provider credentials are write-only: the database returns a configured
/// flag, never the secret itself.
class AiKnowledgeRepository {
  AiKnowledgeRepository([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? SupabaseService.client;

  Future<Map<String, dynamic>> loadConfig() async {
    final raw = await _db.rpc('admin_ai_assistant_config');
    if (raw is! Map) throw const FormatException('Invalid assistant config');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> loadArticles({
    String? search,
    int limit = 200,
  }) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_articles',
      params: <String, dynamic>{'p_search': search, 'p_limit': limit},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> saveConfig({
    required String provider,
    required String model,
    required String baseUrl,
    required String systemPrompt,
    required String tone,
    required int maxReplyChars,
    required String fallbackReply,
    required bool enabled,
    String? apiKey,
  }) async {
    await _db.rpc(
      'admin_ai_assistant_save_config',
      params: <String, dynamic>{
        'p_provider': provider,
        'p_model': model,
        'p_base_url': baseUrl,
        'p_system_prompt': systemPrompt,
        'p_tone': tone,
        'p_max_reply_chars': maxReplyChars,
        'p_fallback_reply': fallbackReply,
        'p_enabled': enabled,
        'p_api_key': apiKey,
      },
    );
  }

  Future<void> saveArticle(Map<String, dynamic> article) async {
    await _db.rpc(
      'admin_ai_knowledge_save_article',
      params: <String, dynamic>{'p_article': article},
    );
  }

  Future<void> deleteArticle(String id) async {
    await _db.rpc(
      'admin_ai_knowledge_delete_article',
      params: <String, dynamic>{'p_id': id},
    );
  }

  Future<List<Map<String, dynamic>>> loadReplyExamples() async {
    final raw = await _db.rpc('admin_ai_reply_examples');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> saveReplyExample(Map<String, dynamic> example) async {
    await _db.rpc(
      'admin_ai_reply_example_save',
      params: <String, dynamic>{'p_example': example},
    );
  }

  Future<void> deleteReplyExample(String id) async {
    await _db.rpc(
      'admin_ai_reply_example_delete',
      params: <String, dynamic>{'p_id': id},
    );
  }
}
