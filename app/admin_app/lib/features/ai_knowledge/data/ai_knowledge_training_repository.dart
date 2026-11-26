import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/ai_knowledge/domain/entities/ai_knowledge_version.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only versioned training API. Drafts are isolated from the shared
/// customer knowledge corpus; a reviewed version is searchable only through
/// the authenticated admin RPC until the admin assistant explicitly uses it.
class AiKnowledgeTrainingRepository {
  AiKnowledgeTrainingRepository([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? SupabaseService.client;

  Future<List<AiKnowledgeVersion>> loadVersions({
    String? knowledgeKey,
    AiKnowledgeVersionStatus? status,
    int limit = 100,
  }) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_version_list',
      params: <String, dynamic>{
        'p_knowledge_key': _blankToNull(knowledgeKey),
        'p_status': status?.value,
        'p_limit': limit.clamp(1, 200).toInt(),
      },
    );
    return _rows(raw).map(AiKnowledgeVersion.fromJson).toList(growable: false);
  }

  Future<AiKnowledgeVersion> loadVersion(String id) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_version_get',
      params: <String, dynamic>{'p_version_id': id},
    );
    return AiKnowledgeVersion.fromJson(_map(raw));
  }

  Future<AiKnowledgeVersion> saveDraft({
    required String knowledgeKey,
    required AiKnowledgeTrainingKind kind,
    required Map<String, dynamic> payload,
    String? versionId,
    DateTime? expectedUpdatedAt,
  }) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_version_save_draft',
      params: <String, dynamic>{
        'p_knowledge_key': knowledgeKey.trim(),
        'p_kind': kind.value,
        'p_payload': payload,
        'p_version_id': _blankToNull(versionId),
        'p_expected_updated_at': expectedUpdatedAt?.toUtc().toIso8601String(),
      },
    );
    return AiKnowledgeVersion.fromJson(_map(raw));
  }

  Future<AiKnowledgeVersion> submitForReview(AiKnowledgeVersion version) =>
      _transition(version, 'submit');

  Future<AiKnowledgeVersion> approve(AiKnowledgeVersion version) =>
      _transition(version, 'approve');

  Future<AiKnowledgeVersion> publish(AiKnowledgeVersion version) =>
      _transition(version, 'publish');

  Future<AiKnowledgeVersion> archive(
    AiKnowledgeVersion version, {
    String? reason,
  }) => _transition(version, 'archive', reason: reason);

  /// Creates a new draft copied from a published/archived revision. Existing
  /// history remains immutable and the restored content must be reviewed again.
  Future<AiKnowledgeVersion> rollbackToDraft(
    AiKnowledgeVersion version, {
    String? reason,
  }) => _transition(version, 'rollback', reason: reason);

  Future<List<AiKnowledgeVersionEvent>> loadHistory(String knowledgeKey) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_version_history',
      params: <String, dynamic>{'p_knowledge_key': knowledgeKey.trim()},
    );
    return _rows(raw)
        .map(AiKnowledgeVersionEvent.fromJson)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchPublished(
    String query, {
    int limit = 6,
  }) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_search_published',
      params: <String, dynamic>{
        'p_query': query.trim(),
        'p_limit': limit.clamp(1, 12).toInt(),
      },
    );
    return _rows(raw);
  }

  Future<AiKnowledgeVersion> _transition(
    AiKnowledgeVersion version,
    String action, {
    String? reason,
  }) async {
    final raw = await _db.rpc(
      'admin_ai_knowledge_version_transition',
      params: <String, dynamic>{
        'p_version_id': version.id,
        'p_action': action,
        'p_expected_updated_at': version.updatedAt.toUtc().toIso8601String(),
        'p_reason': _blankToNull(reason),
      },
    );
    return AiKnowledgeVersion.fromJson(_map(raw));
  }

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid knowledge version');
    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
