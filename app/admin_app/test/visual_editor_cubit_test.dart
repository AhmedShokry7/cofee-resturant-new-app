import 'dart:async';
import 'dart:convert';

import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/preview_protocol.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_merge.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع زائف: يسجّل الاستدعاءات ولا يلمس شبكة.
///
/// كل دالة تحاكي عقد الـ RPC الحي: المسودة تُقرأ null حين لا شيء محفوظ،
/// والنشر يرفض مستندًا غير صالح كأن القاعدة فعلت.
class _FakeVisualEditorRepository extends VisualEditorRepository {
  _FakeVisualEditorRepository();

  Map<String, List<EditableComponent>>? savedDraft;
  DesignTheme? savedTheme;

  /// المسودة الخام على "الخادم" — النشر يجمع منها كما تفعل القاعدة.
  Map<String, dynamic>? draftDocument;
  Completer<void>? saveGate;
  Completer<EditorDraft?>? draftGate;
  final List<Map<String, List<EditableComponent>>> saveSnapshots = [];
  List<Map<String, dynamic>> publishedDocuments = [];
  String? failedPublishDocument;
  int publishCalls = 0;
  final List<PublishedVersionInfo> versions = [];

  void seedVersion(int number) {
    versions.add(
      PublishedVersionInfo(
        id: 'version-$number',
        versionNumber: number,
        publishedAt: DateTime(2026, 1, number),
        schemaVersion: 2,
        note: 'v$number',
      ),
    );
  }

  @override
  Future<EditorDraft?> loadDraft() async => draftGate == null
      ? (draftDocument == null
            ? null
            : EditorDraft(
                componentsByPage: DesignDocumentCodec.parseDocument(
                  draftDocument!,
                ),
                theme: DesignDocumentCodec.themeOf(draftDocument!),
                savedAt: DateTime(2026, 1, 1),
              ))
      : await draftGate!.future;

  @override
  Future<Map<String, dynamic>?> loadDraftDocument() async => draftDocument;

  @override
  Future<Map<String, dynamic>?> loadPublishedDocument() async => null;

  @override
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  }) async {
    final snapshot = {
      for (final entry in componentsByPage.entries)
        entry.key: List<EditableComponent>.of(entry.value),
    };
    saveSnapshots.add(snapshot);
    await saveGate?.future;
    savedDraft = snapshot;
    savedTheme = theme;
    // دمج الصفحات في المسودة المحفوظة + رفع مراجعاتها — نظير دلالات
    // القاعدة فتقرأ publishPages لاحقًا من المستند المدموج نفسه.
    var document = DesignDocumentMerge.withPages(
      base: draftDocument,
      pages: snapshot,
      theme: theme,
    );
    final savedRevisions = <String, int>{};
    for (var i = 0; i < snapshot.keys.length; i++) {
      final pageId = snapshot.keys.elementAt(i);
      savedRevisions[pageId] = i + 1;
      document = DesignDocumentMeta.withPageRevision(document, pageId, i + 1);
    }
    draftDocument = document;
    return PageSaveResult(
      savedRevisions: savedRevisions,
      savedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  }) async {
    publishCalls++;
    final invalid = DesignDocumentCodec.validate(designDocument);
    if (invalid != null) {
      failedPublishDocument = invalid;
      throw StateError('design document cannot be published: $invalid');
    }
    publishedDocuments.add(designDocument);
    final info = PublishedVersionInfo(
      id: 'version-$publishCalls',
      versionNumber: publishCalls,
      publishedAt: DateTime(2026, 1, 2),
      schemaVersion: 2,
    );
    versions.add(info);
    return info;
  }

  @override
  Future<PublishedVersionInfo> publishPages({
    required Set<String> pageIds,
    Map<String, int> knownRevisions = const {},
    bool force = false,
    String? name,
    String? note,
  }) async {
    // نظير تدقيق القاعدة: لا مسودة محفوظة = لا اعتماد.
    final draft = draftDocument;
    if (draft == null) {
      throw StateError('لا توجد مسودة محفوظة للنشر — احفظ أولًا.');
    }
    final document = DesignDocumentMerge.publishedWithPages(
      publishedBase: null,
      draft: draft,
      pageIds: pageIds,
    );
    return publishDesign(document, name: name, note: note);
  }

  @override
  Future<List<PublishedVersionInfo>> listVersions({int limit = 30}) async =>
      versions.reversed.toList();

  @override
  Future<Map<String, dynamic>?> getVersionDocument(String versionId) async =>
      null;

  @override
  Future<PublishedVersionInfo> restoreVersion(String versionId) async {
    throw UnimplementedError('الاسترجاع لا يُختبر على المستودع الزائف هنا');
  }

  // ---- القوالب والتخلص (228) ----

  int discardCalls = 0;
  bool discardShouldFail = false;
  final List<DesignTemplateInfo> templates = [];
  final Map<String, Map<String, dynamic>> templateDocuments = {};

  @override
  Future<void> discardDraft() async {
    if (discardShouldFail) {
      throw StateError('discard failed');
    }
    discardCalls++;
  }

  @override
  Future<List<DesignTemplateInfo>> listTemplates() async => List.of(templates);

  @override
  Future<Map<String, dynamic>?> getTemplateDocument(String templateId) async =>
      templateDocuments[templateId];

  @override
  Future<DesignTemplateInfo> saveTemplate({
    String? id,
    required String name,
    required Map<String, dynamic> document,
  }) async {
    final info = DesignTemplateInfo(
      id: id ?? 'template-${templates.length + 1}',
      name: name,
      schemaVersion: 2,
      updatedAt: DateTime(2026, 1, 3),
    );
    templates.insert(0, info);
    templateDocuments[info.id] = document;
    return info;
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    templates.removeWhere((t) => t.id == templateId);
    templateDocuments.remove(templateId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeVisualEditorRepository repository;
  late VisualEditorCubit cubit;

  setUp(() {
    repository = _FakeVisualEditorRepository();
    cubit = VisualEditorCubit(repository: repository);
  });

  tearDown(() => cubit.close());

  void confirmPreview(String requestId, {bool success = true}) {
    cubit.handlePropertyUpdated({
      'payload': {'requestId': requestId, 'success': success},
    });
  }

  test(
    'publishing does not hang on a failed preview acknowledgement',
    () async {
      await cubit.initialize();
      cubit.addComponent(pageId: 'home', componentType: 'productGrid');
      final first = cubit.pendingMessage!.messageId;
      cubit.undo();
      final latest = cubit.pendingMessage!.messageId;

      confirmPreview(first);
      expect(cubit.state.previewUpdatesPending, 1);
      // النشر يعتمد آخر مسودة محفوظة — بلا حفظ لا نشر.
      expect(await cubit.publish(), isNull);
      expect(repository.publishCalls, 0);
      await cubit.saveDraft();
      expect(await cubit.publish(), isNotNull);
      expect(repository.publishCalls, 1);

      confirmPreview(latest, success: false);
      expect(cubit.state.previewUpdatesPending, 0);
      expect(cubit.state.previewConnection, PreviewConnection.error);
      expect(await cubit.publish(), isNotNull);
      expect(repository.publishCalls, 2);
    },
  );

  test('المعاينة الجاهزة تستقبل المستند بعد اكتمال تحميل المحرر', () async {
    final gate = Completer<EditorDraft?>();
    repository.draftGate = gate;

    final initialization = cubit.initialize();
    cubit.handlePreviewReady(null);
    expect(
      cubit.pendingMessage?.payload['designDocument'],
      isNull,
      reason: 'قد يصل handshake قبل اكتمال قراءة المسودة',
    );

    gate.complete(null);
    await initialization;

    expect(
      cubit.pendingMessage?.type,
      VisualEditorMessageType.applyDesignConfig,
    );
    final document =
        cubit.pendingMessage!.payload['designDocument'] as Map<String, dynamic>;
    expect(document['pages'], isNotEmpty);
  });

  test('تهيئة بلا مسودة تبدأ من تصميم اليوم', () async {
    await cubit.initialize();
    expect(cubit.state.status, VisualEditorStatus.ready);
    expect(cubit.state.getComponentsForPage('home'), hasLength(8));
    expect(
      cubit.state.getComponentsForPage('splash').single.componentType,
      'splashSettings',
    );
    expect(cubit.state.isDirty, isFalse);
    expect(cubit.canUndo, isFalse);
  });

  test('إعدادات الافتتاحية مفردة ولا يمكن تكرارها من المكتبة', () async {
    await cubit.initialize();
    final before = cubit.state.getComponentsForPage('splash');
    cubit.addComponent(pageId: 'splash', componentType: 'splashSettings');
    expect(cubit.state.getComponentsForPage('splash'), before);
    expect(cubit.state.selectedComponentId, before.single.componentId);
  });

  test('الإضافة ترفض مكوّنًا غير مسموح للصفحة', () async {
    await cubit.initialize();
    final before = cubit.state.getComponentsForPage('categories');

    cubit.addComponent(pageId: 'categories', componentType: 'header');

    expect(cubit.state.getComponentsForPage('categories'), before);
    expect(cubit.state.isDirty, isFalse);
  });

  test('الإضافة ترفض حاوية أب من صفحة أخرى', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'column');
    final parent = cubit.state.getComponentsForPage('home').last;
    final categoriesBefore = cubit.state.getComponentsForPage('categories');

    cubit.addComponent(
      pageId: 'categories',
      componentType: 'text',
      parentId: parent.componentId,
    );

    expect(cubit.state.getComponentsForPage('categories'), categoriesBefore);
  });

  test('إضافة مكوّن يترك أثرًا في الشجرة والمستند ويدفع مسودة', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final components = cubit.state.getComponentsForPage('home');
    expect(components, hasLength(9));
    expect(components.last.componentType, 'productGrid');
    expect(cubit.state.isDirty, isTrue);
    expect(cubit.canUndo, isTrue);
    expect(cubit.pendingMessage?.type, VisualEditorMessageType.addComponent);
  });

  test('ترتيب مكوّن يعيد الفهرسة ويرسل الرسالة', () async {
    await cubit.initialize();
    cubit
      ..addComponent(pageId: 'home', componentType: 'productGrid')
      ..addComponent(pageId: 'home', componentType: 'button');
    final button = cubit.state.getComponentsForPage('home').last;
    expect(button.componentType, 'button');
    cubit.reorderComponent(button.componentId, 0);
    final types = cubit.state
        .getComponentsForPage('home')
        .map((c) => c.componentType)
        .toList();
    expect(types.first, 'button');
    expect(types[1], 'header');
    expect(cubit.state.getComponentsForPage('home').first.index, 0);
    expect(
      cubit.pendingMessage?.type,
      VisualEditorMessageType.reorderComponent,
    );
  });

  test('حذف محمي: مكوّن بلا عملية delete لا يُحذف', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'header');
    final header = cubit.state.getComponentsForPage('home').last;
    expect(header.componentType, 'header');
    cubit.deleteComponent(header.componentId);
    expect(
      cubit.state.getComponentsForPage('home'),
      hasLength(9),
      reason: 'header محمي بلا delete في allowedOperations',
    );
  });

  test('حذف مكوّن مسموح يحذفه فعلًا', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final grid = cubit.state.getComponentsForPage('home').last;
    cubit.deleteComponent(grid.componentId);
    expect(cubit.state.getComponentsForPage('home'), hasLength(8));
  });

  test('خطأ المعاينة لا يحوّل حالة المحرر الجاهز إلى فشل', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    expect(cubit.state.previewUpdatesPending, 1);
    cubit.handlePreviewError({'error': 'preview unavailable'});
    expect(cubit.state.status, VisualEditorStatus.ready);
    expect(cubit.state.previewUpdatesPending, 0);
    expect(cubit.state.previewConnection, PreviewConnection.error);
    expect(cubit.state.errorMessage, 'preview unavailable');
  });

  test(
    'تبديل الصفحة يبني تحديدًا جديدًا خاصًا بها والتراجع يحدّث الخصائص المحددة',
    () async {
      await cubit.initialize();
      cubit.addComponent(pageId: 'home', componentType: 'productGrid');
      final grid = cubit.state.getComponentsForPage('home').last;
      cubit.selectComponent(grid.componentId);
      cubit.updateProperty(
        componentId: grid.componentId,
        propertyKey: 'columns',
        value: 3,
      );
      cubit.undo();
      expect(cubit.state.selectedComponent?.componentId, grid.componentId);
      expect(cubit.state.selectedComponent?.properties['columns'], 2);
      // تبديل الصفحة لا يحمل تحديد الصفحة السابقة؛ الصفحات المدمجة تُحدد
      // أول عنصر محتوى فيها فورًا (لوحة الخصائص لا تفتح فارغة) — وعنصر
      // «سلة» الأول عنوان، لا شبكة الصفحة الرئيسية.
      cubit.loadPage('cart');
      expect(cubit.state.selectedComponentId, isNot(grid.componentId));
      final cartHeading = cubit.state.getComponentsForPage('cart').first;
      expect(cubit.state.selectedComponentId, cartHeading.componentId);
    },
  );

  test('فتح الافتتاحية يحدد إعداداتها فتظهر أدوات الصورة واللون', () async {
    await cubit.initialize();
    cubit.loadPage('splash');

    expect(
      cubit.state.selectedComponent?.componentType,
      'splashSettings',
      reason: 'صفحة الافتتاحية عقدة واحدة؛ لا تترك المفتش فارغًا',
    );
    expect(cubit.state.selectedComponentId, isNotNull);
  });

  test('تغيير صورة ولون الافتتاحية يصل إلى مستند المعاينة كاملًا', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final homeGrid = cubit.state.getComponentsForPage('home').last;
    cubit.loadPage('splash');
    final splashId = cubit.state.selectedComponentId!;

    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'imageUrl',
      value: 'https://example.invalid/new-splash.png',
    );
    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'backgroundColor',
      value: '#2E7D32',
    );
    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'text_ar',
      value: 'أهلاً بك',
    );
    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'text_en',
      value: 'Welcome',
    );
    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'textColor',
      value: '#F5F5F5',
    );
    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'durationMs',
      value: 2400,
    );
    cubit.updateProperty(
      componentId: splashId,
      propertyKey: 'animation',
      value: 'fade',
    );

    expect(
      cubit.pendingMessage?.type,
      VisualEditorMessageType.applyDesignConfig,
    );
    expect(cubit.pendingMessage?.payload['awaitPreviewAck'], isTrue);
    final document =
        cubit.pendingMessage!.payload['designDocument'] as Map<String, dynamic>;
    final pages = document['pages'] as List;
    final splashPage = pages.firstWhere(
      (page) => page is Map && page['page'] == 'splash',
    ) as Map;
    final node =
        ((splashPage['root'] as Map)['children'] as List).single as Map;
    final properties = node['properties'] as Map;

    expect(properties['imageUrl'], 'https://example.invalid/new-splash.png');
    expect(properties['backgroundColor'], '#2E7D32');
    expect(properties['text_ar'], 'أهلاً بك');
    expect(properties['text_en'], 'Welcome');
    expect(properties['textColor'], '#F5F5F5');
    expect(properties['durationMs'], 2400);
    expect(properties['animation'], 'fade');
    expect(properties['imageVisible'], isTrue);
    expect(properties['imageFit'], 'contain');
    expect(
      cubit.state
          .getComponentsForPage('home')
          .firstWhere(
            (component) => component.componentId == homeGrid.componentId,
          )
          .properties['columns'],
      homeGrid.properties['columns'],
      reason: 'Editing Splash must keep components on other pages intact.',
    );
  });

  test('حفظ قديم لا يمسح dirty ولا يتسابق مع حفظ أحدث', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final grid = cubit.state.getComponentsForPage('home').last;
    final gate = Completer<void>();
    repository.saveGate = gate;

    final firstSave = cubit.saveDraft();
    await Future<void>.delayed(Duration.zero);
    cubit.updateProperty(
      componentId: grid.componentId,
      propertyKey: 'columns',
      value: 3,
    );
    final secondSave = cubit.saveDraft();
    await Future<void>.delayed(Duration.zero);
    expect(repository.saveSnapshots, hasLength(1));

    gate.complete();
    await Future.wait([firstSave, secondSave]);
    expect(repository.saveSnapshots, hasLength(2));
    expect(
      repository.saveSnapshots.last['home']!
          .firstWhere((component) => component.componentId == grid.componentId)
          .properties['columns'],
      3,
    );
    expect(cubit.state.isDirty, isFalse);
  });

  test('تراجع وإعادة يرجعان الشجرة بالحرف', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final afterAdd = cubit.state.getComponentsForPage('home').length;
    cubit.addComponent(pageId: 'home', componentType: 'button');
    final afterSecond = cubit.state.getComponentsForPage('home').length;
    expect(afterSecond, afterAdd + 1);
    cubit.undo();
    expect(cubit.state.getComponentsForPage('home'), hasLength(afterAdd));
    cubit.redo();
    expect(cubit.state.getComponentsForPage('home'), hasLength(afterSecond));
    expect(cubit.canUndo, isTrue);
  });

  test('تحديث خاصية يتقيد بحدود التحقق', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final grid = cubit.state.getComponentsForPage('home').last;
    expect(grid.componentType, 'productGrid');
    // أعمدة فوق السقف (4) ترفض.
    cubit.updateProperty(
      componentId: grid.componentId,
      propertyKey: 'columns',
      value: 9,
    );
    final afterInvalid = cubit.state
        .findComponent(grid.componentId)!
        .properties['columns'];
    expect(afterInvalid, 2, reason: 'القيمة الافتراضية لم تتغير');
    // قيمة داخل الحدود تُقبل.
    cubit.updateProperty(
      componentId: grid.componentId,
      propertyKey: 'columns',
      value: 3,
    );
    expect(
      cubit.state.findComponent(grid.componentId)!.properties['columns'],
      3,
    );
  });

  test('إعادة خاصية اختيارية إلى الافتراضي تحذف التجاوز من المستند', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'welcome', componentType: 'welcomeTitle');
    final title = cubit.state.getComponentsForPage('welcome').last;
    cubit.updateProperty(
      componentId: title.componentId,
      propertyKey: 'size',
      value: 28,
    );
    expect(
      cubit.state.findComponent(title.componentId)!.properties['size'],
      28,
    );

    cubit.resetProperty(componentId: title.componentId, propertyKey: 'size');

    expect(
      cubit.state.findComponent(title.componentId)!.properties,
      isNot(contains('size')),
    );
    final document = DesignDocumentCodec.document(cubit.state.componentsByPage);
    final root =
        (document['pages'] as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .singleWhere((page) => page['page'] == 'welcome')['root']
            as Map;
    final titleNode = (root['children'] as List<dynamic>)
        .whereType<Map>()
        .singleWhere((node) => node['id'] == title.componentId);
    expect(titleNode['properties'], isNot(contains('size')));
  });

  test('إظهار وإخفاء يمرر عبر updateProperty', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final grid = cubit.state.getComponentsForPage('home').last;
    expect(grid.componentType, 'productGrid');
    cubit.toggleComponentVisibility(grid.componentId);
    expect(
      cubit.state.findComponent(grid.componentId)!.properties['visible'],
      isFalse,
    );
  });

  test('النشر يعتمد آخر مسودة محفوظة ثم يحمل الإضافات بعد حفظها', () async {
    // بلا مسودة محفوظة لا نشر: الاعتماد من المسودة لا من الحالة المفتوحة.
    await cubit.initialize();
    expect(await cubit.publish(), isNull);
    expect(repository.publishCalls, 0);
    expect(cubit.state.errorMessage, contains('مسودة'));

    // تعديل + حفظ ثم النشر: تصميم اليوم (8) + المضاف (1) كما كتبت.
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    confirmPreview(cubit.pendingMessage!.messageId);
    await cubit.saveDraft();
    final first = await cubit.publish();
    expect(first, isNotNull);
    expect(repository.publishedDocuments, hasLength(1));
    expect(
      DesignDocumentCodec.validate(repository.publishedDocuments.last),
      isNull,
    );
    // المستند المنشور بمفاتيح العقد التي يرسمها الهاتف، بترتيب تصميم اليوم
    // ثم المضاف.
    final pages = repository.publishedDocuments.last['pages'] as List;
    expect(pages.first['page'], 'home');
    final children = pages.first['root']['children'] as List;
    expect(children, hasLength(9));
    expect(
      children.map((child) => child['type']),
      contains('section.product_grid'),
      reason: 'مفتاح العقد كما يرسمه الهاتف، لا المفتاح الداخلي للمحرّر',
    );
  });

  test('النشر يمرر المستند عبر تدقيق قبل القاعدة', () async {
    // التدقيق انتقل إلى طبقة المستودع/القاعدة (تدقيق المستند المجمّع
    // من المسودة) — هذا الاختبار يثبت أن مسودة سليمة تعبر بلا رفض
    // وبرسالة واضحة لو فشلت.
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'bannerCarousel');
    confirmPreview(cubit.pendingMessage!.messageId);
    await cubit.saveDraft();
    final version = await cubit.publish();
    expect(version, isNotNull);
    expect(repository.failedPublishDocument, isNull);
  });

  test('حفظ المسودة يمر عبر المستودع بلا sessionId', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    await cubit.saveDraft();
    expect(repository.savedDraft, isNotNull);
    expect(repository.savedDraft!['home'], hasLength(9));
    expect(cubit.state.isDirty, isFalse);
  });

  test('معاينة إصدار غير موجود تعرض رسالة واضحة', () async {
    await cubit.initialize();
    final result = await cubit.previewVersion('missing-version');
    expect(result, isFalse);
    expect(cubit.state.errorMessage, contains('تعذر تحميل مستند الإصدار'));
  });

  test('سجل الإصدارات يقرأ من المستودع بترتيبه', () async {
    repository
      ..seedVersion(1)
      ..seedVersion(2);
    await cubit.initialize();
    final versions = await cubit.loadVersions();
    expect(versions.first.versionNumber, 2);
    expect(versions.last.versionNumber, 1);
  });

  // ---------- الأعمدة المتداخلة ----------

  test('إضافة ابن داخل عمود يُدرج في موضعه العمقي', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'column');
    final column = cubit.state.getComponentsForPage('home').last;
    cubit.addComponent(
      pageId: 'home',
      componentType: 'text',
      parentId: column.componentId,
    );
    cubit.addComponent(
      pageId: 'home',
      componentType: 'button',
      parentId: column.componentId,
    );
    final flat = cubit.state.getComponentsForPage('home');
    // 8 أقسام اليوم + العمود + ابناه.
    expect(flat, hasLength(11));
    final children = flat.where((c) => c.parentId == column.componentId);
    expect(children.map((c) => c.componentType), ['text', 'button']);
    expect(children.first.index, 0);
    expect(children.last.index, 1);
    // الترتيب العمقي: النص بعد العمود مباشرة، ثم الزر. العمود أعيد فهرسته
    // بعد الإضافات، فنبحث عنه بمعرّفه لا بهويّته القديمة.
    final columnInFlat = flat.firstWhere(
      (c) => c.componentId == column.componentId,
    );
    final columnAt = flat.indexOf(columnInFlat);
    expect(flat[columnAt + 1].componentType, 'text');
    expect(flat[columnAt + 2].componentType, 'button');
  });

  test('التداخل المحظور يُرفض: عمود داخل نص لا يجوز', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'text');
    final text = cubit.state.getComponentsForPage('home').last;
    final before = cubit.state.getComponentsForPage('home').length;
    cubit.addComponent(
      pageId: 'home',
      componentType: 'column',
      parentId: text.componentId,
    );
    expect(cubit.state.getComponentsForPage('home'), hasLength(before));
  });

  test('حذف عمود يحذف شجرته كلها بلا أبناء أيتام', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'column');
    final column = cubit.state.getComponentsForPage('home').last;
    cubit.addComponent(
      pageId: 'home',
      componentType: 'text',
      parentId: column.componentId,
    );
    cubit.addComponent(
      pageId: 'home',
      componentType: 'button',
      parentId: column.componentId,
    );
    cubit.deleteComponent(column.componentId);
    final flat = cubit.state.getComponentsForPage('home');
    expect(flat, hasLength(8));
    expect(flat.where((c) => c.parentId != null), isEmpty);
  });

  test('نسخ عمود ينسخ أبناءه بمعرّفات جديدة', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'column');
    final column = cubit.state.getComponentsForPage('home').last;
    cubit.addComponent(
      pageId: 'home',
      componentType: 'text',
      parentId: column.componentId,
    );
    cubit.duplicateComponent(column.componentId);
    final flat = cubit.state.getComponentsForPage('home');
    // 8 + العمود + نصه + نسخة العمود + نسخة النص.
    expect(flat, hasLength(12));
    final columns = flat.where((c) => c.componentType == 'column').toList();
    expect(columns, hasLength(2));
    final duplicatedColumn = columns.last;
    expect(duplicatedColumn.componentId, isNot(column.componentId));
    expect(
      flat.where((c) => c.parentId == duplicatedColumn.componentId),
      hasLength(1),
    );
  });

  test('إعادة ترتيب بين الإخوة يبني القائمة العمقية من المستند', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'column');
    final column = cubit.state.getComponentsForPage('home').last;
    cubit.addComponent(
      pageId: 'home',
      componentType: 'text',
      parentId: column.componentId,
    );
    cubit.addComponent(
      pageId: 'home',
      componentType: 'button',
      parentId: column.componentId,
    );
    final flatBefore = cubit.state.getComponentsForPage('home');
    final button = flatBefore.last;
    cubit.reorderComponent(button.componentId, 0);
    final children = cubit.state
        .getComponentsForPage('home')
        .where((c) => c.parentId == column.componentId)
        .toList();
    expect(children.map((c) => c.componentType), ['button', 'text']);
    expect(children.first.index, 0);
  });

  // ---------- طبقة الشكل ----------

  test('updateTheme يترك أثر تراجع ويغير الطبقة الحيّة', () {
    const theme = DesignTheme(
      colors: {DesignColorRole.primary: '#2E7D32'},
      textScale: 'large',
    );
    cubit.updateTheme(theme);
    expect(cubit.theme.colors, theme.colors);
    expect(cubit.theme.textScale, 'large');
    expect(cubit.canUndo, isTrue);
    cubit.undo();
    expect(cubit.theme.colors, isEmpty);
    expect(cubit.theme.textScale, isNull);
  });

  // ---------- التخلص من المسودة ----------

  test('التخلص الناجح يمسح المسودة ويعيد البدء من تصميم اليوم', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final ok = await cubit.discardDraft();
    expect(ok, isTrue);
    expect(repository.discardCalls, 1);
    expect(cubit.state.getComponentsForPage('home'), hasLength(8));
    expect(cubit.canUndo, isFalse);
  });

  test('فشل التخلص يبقي الحالة المحلية كما هي', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    repository.discardShouldFail = true;
    final ok = await cubit.discardDraft();
    expect(ok, isFalse);
    expect(cubit.state.getComponentsForPage('home'), hasLength(9));
    expect(cubit.state.errorMessage, contains('تعذر التخلص'));
  });

  // ---------- القوالب ----------

  test('حفظ قالب يكتب مستندًا صالحًا ويعيد بياناته', () async {
    await cubit.initialize();
    final template = await cubit.saveCurrentAsTemplate('رمضان');
    expect(template, isNotNull);
    expect(template!.name, 'رمضان');
    expect(repository.templateDocuments[template.id], isNotNull);
    expect(
      DesignDocumentCodec.validate(repository.templateDocuments[template.id]!),
      isNull,
    );
  });

  test('اسم قالب فارغ أو طويل يُرفض قبل الاتصال', () async {
    await cubit.initialize();
    expect(await cubit.saveCurrentAsTemplate('   '), isNull);
    expect(await cubit.saveCurrentAsTemplate('x' * 61), isNull);
    expect(repository.templates, isEmpty);
  });

  test('تطبيق قالب يستبدل الشجرة والشكل على المسودة فقط', () async {
    await cubit.initialize();
    // قالب مسجّل مسبقًا في المستودع الزائف.
    final document = DesignDocumentCodec.document({
      'home': DesignDocumentCodec.defaultHomeComponents(),
    });
    final template = await repository.saveTemplate(
      name: 'قالب اليوم',
      document: document,
    );
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final ok = await cubit.applyTemplate(template.id);
    expect(ok, isTrue);
    // القالب أصل 8 أقسام: الإضافة سقطت والقالب حلّ محلها.
    expect(cubit.state.getComponentsForPage('home'), hasLength(8));
    expect(cubit.canUndo, isTrue);
    // المنشور لا يُلمس.
    expect(repository.publishedDocuments, isEmpty);
  });

  test('تطبيق قالب مفقود يفشل برسالة مفهومة', () async {
    await cubit.initialize();
    expect(await cubit.applyTemplate('missing-template'), isFalse);
    expect(cubit.state.errorMessage, contains('القالب غير موجود'));
  });

  test('حذف قالب يمر عبر المستودع بلا مساس بالمسودة', () async {
    await cubit.initialize();
    final template = await cubit.saveCurrentAsTemplate('مؤقت');
    final ok = await cubit.deleteTemplate(template!.id);
    expect(ok, isTrue);
    expect(repository.templates, isEmpty);
  });

  // ---------- لغة ومظهر معاينة العميل ----------

  group('إعدادات عرض المعاينة', () {
    test('التبديل يرسل رسالته بلا مسودة ولا تراجع ولا حفظ', () async {
      await cubit.initialize();

      cubit.togglePreviewLanguage();
      expect(cubit.state.previewLanguage, PreviewLanguage.english);
      expect(cubit.pendingMessage?.type, VisualEditorMessageType.setLanguage);
      expect(cubit.pendingMessage?.payload, {'language': 'en'});

      cubit.togglePreviewThemeMode();
      expect(cubit.state.previewThemeMode, PreviewThemeMode.dark);
      expect(cubit.pendingMessage?.type, VisualEditorMessageType.setThemeMode);
      expect(cubit.pendingMessage?.payload, {'mode': 'dark'});

      expect(cubit.state.isDirty, isFalse);
      expect(cubit.canUndo, isFalse);
      expect(cubit.canRedo, isFalse);
      expect(repository.saveSnapshots, isEmpty);
      expect(repository.publishCalls, 0);
    });

    test('الإعدادات الحالية تُرفق برسالة تهيئة الإطار', () async {
      await cubit.initialize();
      cubit.setPreviewLanguage(PreviewLanguage.english);
      cubit.setPreviewThemeMode(PreviewThemeMode.dark);

      cubit.handlePreviewReady(null);

      expect(
        cubit.pendingMessage?.type,
        VisualEditorMessageType.previewInitialize,
      );
      expect(cubit.pendingMessage?.payload['previewLanguage'], 'en');
      expect(cubit.pendingMessage?.payload['previewThemeMode'], 'dark');
      expect(cubit.state.isDirty, isFalse);
    });

    test('النشر لا يحمل إعدادات المعاينة', () async {
      await cubit.initialize();
      cubit.setPreviewLanguage(PreviewLanguage.english);
      cubit.setPreviewThemeMode(PreviewThemeMode.dark);

      // النشر يعتمد المسودة المحفوظة — تعديل وحفظ أولًا لتحصل الصفحة على
      // مراجعة في المسودة.
      cubit.addComponent(pageId: 'home', componentType: 'productGrid');
      confirmPreview(cubit.pendingMessage!.messageId);
      await cubit.saveDraft();
      final version = await cubit.publish();

      expect(version, isNotNull);
      expect(repository.publishedDocuments, hasLength(1));
      final published = jsonEncode(repository.publishedDocuments.single);
      expect(published, isNot(contains('previewLanguage')));
      expect(published, isNot(contains('previewThemeMode')));
      expect(published, isNot(contains('"language":"en"')));
      expect(published, isNot(contains('"mode":"dark"')));
    });
  });
}
