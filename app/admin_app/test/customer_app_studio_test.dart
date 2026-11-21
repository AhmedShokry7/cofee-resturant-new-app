import 'package:admin_app/features/customer_app_studio/data/models/preview_protocol.dart';
import 'package:admin_app/features/customer_app_studio/data/models/studio_registry.dart';
import 'package:admin_app/features/customer_app_studio/data/repositories/studio_draft_repository.dart';
import 'package:admin_app/features/customer_app_studio/presentation/manager/studio_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDraftRepository extends StudioDraftRepository {
  final drafts = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> load(String pageId) async => drafts[pageId];

  @override
  Future<void> save(String pageId, Map<String, Object?> draft) async {
    drafts[pageId] = draft;
  }
}

void main() {
  group('Customer App Studio registries', () {
    test('page registry has stable unique page IDs and argument routes', () {
      final ids = studioPages.map((page) => page.id).toSet();
      expect(ids.length, studioPages.length);
      expect(studioPages, hasLength(38));
      expect(studioArgumentRoutes, isNotEmpty);
      expect(
        studioPages.where((page) => page.id == 'home').single.support,
        'Partially Editable',
      );
      expect(
        studioPages.where((page) => page.id == 'categories').single.support,
        'Partially Editable',
      );
    });

    test('component registry maps only customer runtime renderers', () {
      expect(
        studioComponents.map((component) => component.type).toSet().length,
        studioComponents.length,
      );
      expect(studioComponents, hasLength(9));
      for (final component in studioComponents) {
        expect(component.schemaVersion, greaterThan(0));
        expect(component.renderer, startsWith('DesignSectionRenderers.'));
      }
    });

    test('property values are validated against schema types and bounds', () {
      final fontSize = studioComponents
          .singleWhere((component) => component.type == 'section.text')
          .properties
          .singleWhere((property) => property.key == 'size');
      final color = studioComponents
          .singleWhere((component) => component.type == 'section.text')
          .properties
          .singleWhere((property) => property.key == 'color');
      expect(validateStudioValue(fontSize, 18), isNull);
      expect(validateStudioValue(fontSize, 99), isNotNull);
      expect(validateStudioValue(color, '#19AABB'), isNull);
      expect(validateStudioValue(color, 'red'), isNotNull);
    });
  });

  group('Customer App Studio draft operations', () {
    late _MemoryDraftRepository repository;
    late StudioCubit cubit;

    setUp(() async {
      repository = _MemoryDraftRepository();
      cubit = StudioCubit(repository);
      await cubit.restore();
    });

    tearDown(() async => cubit.close());

    test(
      'add, edit, reorder, remove, undo and redo change the draft tree',
      () async {
        cubit.addNode('section.text');
        final firstId = cubit.state.selectedNodeId!;
        expect(cubit.state.findNode(firstId)?.props['text'], 'Edit this text');
        cubit.updateProperty('text', 'Fresh coffee');
        expect(cubit.state.findNode(firstId)?.props['text'], 'Fresh coffee');
        cubit.addNode('section.heading');
        final secondId = cubit.state.selectedNodeId!;
        cubit.moveSelected(-1);
        expect(cubit.state.nodes.first.id, secondId);
        cubit.removeSelected();
        expect(cubit.state.findNode(secondId), isNull);
        cubit.undo();
        expect(cubit.state.findNode(secondId), isNotNull);
        cubit.redo();
        expect(cubit.state.findNode(secondId), isNull);
        expect(cubit.state.canUndo, isTrue);
        await cubit.saveDraft();
        expect(repository.drafts['home']?['nodes'], isA<List>());
      },
    );

    test('nested nodes are validated and included in preview document', () {
      cubit.addNode('section.column');
      final parentId = cubit.state.selectedNodeId!;
      cubit.addNode('section.text', parentId: parentId);
      final parent = cubit.state.findNode(parentId)!;
      expect(parent.children, hasLength(1));
      expect(cubit.validateDocument(cubit.state.nodes), isNull);
      final page = (cubit.previewDocument['pages'] as List).single as Map;
      final root = page['root'] as Map;
      expect((root['children'] as List).single, isA<Map>());
    });

    test('page switching preserves and restores independent drafts', () async {
      cubit.addNode('section.text');
      cubit.updateProperty('text', 'Home draft');
      await cubit.saveDraft();
      await cubit.selectPage('categories');
      cubit.addNode('section.text');
      cubit.updateProperty('text', 'Category draft');
      await cubit.saveDraft();
      await cubit.selectPage('home');
      expect(cubit.state.nodes.single.props['text'], 'Home draft');
      expect(repository.drafts['categories'], isNotNull);
    });

    test('preview protocol encodes and validates a typed draft message', () {
      final message = StudioPreviewMessage(
        sessionId: 'session-a',
        type: StudioPreviewMessageType.applyDesignConfig,
        payload: cubit.previewDocument,
        messageId: 'message-a',
      );
      expect(
        StudioPreviewMessage.decode(
          message.toJson(),
          sessionId: 'session-a',
        )?.type,
        StudioPreviewMessageType.applyDesignConfig,
      );
      expect(
        StudioPreviewMessage.decode(message.toJson(), sessionId: 'wrong'),
        isNull,
      );
    });
  });
}
