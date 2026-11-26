import 'package:admin_app/features/ai_knowledge/data/ai_knowledge_training_repository.dart';
import 'package:admin_app/features/ai_knowledge/domain/entities/ai_knowledge_version.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/stub_supabase_client.dart';

void main() {
  group('AI knowledge training repository', () {
    test('creates a typed draft through the admin-only version API', () async {
      final client = StubSupabaseClient(payload: _version(status: 'draft'));
      final repository = AiKnowledgeTrainingRepository(client);

      final draft = await repository.saveDraft(
        knowledgeKey: 'opening_hours',
        kind: AiKnowledgeTrainingKind.article,
        payload: const {
          'title_ar': 'ساعات العمل',
          'title_en': 'Opening hours',
          'body_ar': 'تختلف حسب الفرع.',
          'body_en': 'Hours vary by branch.',
        },
      );

      expect(draft.status, AiKnowledgeVersionStatus.draft);
      expect(draft.knowledgeKey, 'opening_hours');
      expect(client.lastRpc, 'admin_ai_knowledge_version_save_draft');
      expect(client.lastParams?['p_kind'], 'article');
      expect(client.lastParams?['p_payload'], contains('title_ar'));
    });

    test('transition binds an approval to a specific version and timestamp', () async {
      final client = StubSupabaseFunctions(
        responses: {
          'admin_ai_knowledge_version_transition': _version(
            status: 'pending_review',
          ),
        },
      );
      final repository = AiKnowledgeTrainingRepository(client);
      final draft = AiKnowledgeVersion.fromJson(_version(status: 'draft'));

      final pending = await repository.submitForReview(draft);

      expect(pending.status, AiKnowledgeVersionStatus.pendingReview);
      expect(
        client.params['admin_ai_knowledge_version_transition'],
        containsPair('p_version_id', draft.id),
      );
      expect(
        client.params['admin_ai_knowledge_version_transition'],
        containsPair('p_action', 'submit'),
      );
      expect(
        client
            .params['admin_ai_knowledge_version_transition']?['p_expected_updated_at'],
        isNotNull,
      );
    });

    test(
      'published admin search uses a separate RPC from shared knowledge',
      () async {
        final client = StubSupabaseClient(
          payload: const <Map<String, dynamic>>[
            {'knowledge_key': 'opening_hours', 'kind': 'article', 'version': 2},
          ],
        );
        final repository = AiKnowledgeTrainingRepository(client);

        final results = await repository.searchPublished('opening hours');

        expect(results, hasLength(1));
        expect(client.lastRpc, 'admin_ai_knowledge_search_published');
        expect(client.lastParams?['p_query'], 'opening hours');
      },
    );

    test(
      'rejects unknown lifecycle states instead of silently mapping them',
      () {
        expect(
          () => AiKnowledgeVersion.fromJson(_version(status: 'approved-ish')),
          throwsFormatException,
        );
      },
    );
  });
}

Map<String, dynamic> _version({required String status}) => {
  'id': '98a00000-0000-4000-8000-000000000001',
  'knowledge_key': 'opening_hours',
  'kind': 'article',
  'version': 1,
  'payload': {
    'title_ar': 'ساعات العمل',
    'title_en': 'Opening hours',
    'body_ar': 'تختلف حسب الفرع.',
    'body_en': 'Hours vary by branch.',
  },
  'status': status,
  'created_by': '98a00000-0000-4000-8000-000000000002',
  'created_at': '2026-11-25T00:00:00Z',
  'updated_at': '2026-11-25T00:01:00Z',
};
