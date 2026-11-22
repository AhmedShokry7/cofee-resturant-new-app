import 'package:admin_app/features/visual_editor/domain/component_registry.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_merge.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';

/// نموذج قاعدة البيانات بعقود 226/254: مسودة ومنشور صفان في
/// core.app_settings، وإصدارات صفوف غير قابلة للتعديل، ومراجعات صفحات
/// داخل meta، وفحص تعارض ذري (فحص + كتابة في خطوة واحدة بلا قراءة
/// وسيطة) — لاختبار منطق المحرّر ضد دلالات القاعدة الفعلية.
class _ServerDesignStore {
  Map<String, dynamic>? draft;
  Map<String, dynamic>? published;
  final List<Map<String, dynamic>> versionRows = [];
  final List<String> auditLog = [];

  static int _revisionOf(Map<String, dynamic>? document, String pageId) =>
      DesignDocumentMeta.pageRevision(document, pageId);

  /// حفظ صفحة ذري: فحص المراجعة من الصف الحالي ثم الكتابة في نفس
  /// الخطوة — لا نافذة سباق بين القراءة والكتابة.
  int savePage(
    String pageId,
    List<EditableComponent> components, {
    required DesignTheme theme,
    required int expectedRevision,
    bool force = false,
  }) {
    final current = _revisionOf(draft, pageId);
    if (!force && current > expectedRevision) {
      throw PageRevisionConflict(
        pageId: pageId,
        serverRevision: current,
        knownRevision: expectedRevision,
      );
    }
    var document = DesignDocumentMerge.withPage(
      base: draft ?? const <String, dynamic>{},
      pageId: pageId,
      components: components,
      theme: theme,
    );
    document = DesignDocumentMeta.withPageRevision(document, pageId, current + 1);
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      throw StateError('المستند غير صالح: $invalid');
    }
    draft = document;
    auditLog.add('draft.save:$pageId:${current + 1}');
    return current + 1;
  }

  /// مسح الصفحة من المسودة — حذف صريح يمر بالمراجعة نفسها.
  int removePage(
    String pageId, {
    required int expectedRevision,
    bool force = false,
  }) {
    final current = _revisionOf(draft, pageId);
    if (!force && current > expectedRevision) {
      throw PageRevisionConflict(
        pageId: pageId,
        serverRevision: current,
        knownRevision: expectedRevision,
      );
    }
    var document = DesignDocumentMerge.withPage(
      base: draft ?? const <String, dynamic>{},
      pageId: pageId,
      components: const [],
      theme: null,
    );
    document = DesignDocumentMeta.withPageRevision(document, pageId, current + 1);
    draft = document;
    auditLog.add('draft.remove:$pageId:${current + 1}');
    return current + 1;
  }

  /// نشر صفحات: التجميع داخل خطوة واحدة من المسودة + المنشور الحاليين
  /// (بلا قراءة وسيطة) — نظير معاملة 254 المقفلة.
  Map<String, dynamic> publishPages(
    Set<String> pageIds, {
    required Map<String, int> expectedRevisions,
    required String? name,
    required String? note,
  }) {
    if (draft == null) {
      throw StateError('لا توجد مسودة محفوظة للنشر');
    }
    for (final pageId in pageIds) {
      final current = _revisionOf(draft, pageId);
      final expected = expectedRevisions[pageId] ?? 0;
      if (current == 0 && !(draft!['pages'] as List).any((p) => p['page'] == pageId)) {
        throw StateError('الصفحة $pageId ليست محفوظة في المسودة');
      }
      if (current > expected) {
        throw PageRevisionConflict(
          pageId: pageId,
          serverRevision: current,
          knownRevision: expected,
        );
      }
    }
    final document = DesignDocumentMerge.publishedWithPages(
      publishedBase: published,
      draft: draft,
      pageIds: pageIds,
    );
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      throw StateError('المستند غير صالح للنشر: $invalid');
    }
    published = document;
    versionRows.add({
      'id': 'version-${versionRows.length + 1}',
      'version_number': versionRows.length + 1,
      'document': document,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
    });
    auditLog.add('publish:${pageIds.toList()..sort()}');
    return document;
  }

  /// نشر مستند كامل (مسار 226/253) — يستخدم للاسترجاع والقوالب.
  Map<String, dynamic> publishWholeDocument(Map<String, dynamic> document) {
    final invalid = DesignDocumentCodec.validate(document);
    if (invalid != null) {
      throw StateError('المستند غير صالح للنشر: $invalid');
    }
    published = document;
    versionRows.add({
      'id': 'version-${versionRows.length + 1}',
      'version_number': versionRows.length + 1,
      'document': document,
    });
    auditLog.add('publish:whole');
    return document;
  }
}

/// مستودع يعمل فوق [_ServerDesignStore] بمنطق المحرّر الحقيقي:
/// نفس خطوات [SupabaseVisualEditorRepository] (قراءة حية → فحص مراجعة →
/// دمج → كتابة) — الفرق فقط أن القاعدة نموذج في الذاكرة.
class _ServerBackedRepository extends VisualEditorRepository {
  _ServerBackedRepository(this.server);

  final _ServerDesignStore server;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>?> loadDraftDocument() async => server.draft;

  @override
  Future<Map<String, dynamic>?> loadPublishedDocument() async =>
      server.published;

  @override
  Future<EditorDraft?> loadDraft() async {
    final document = server.draft;
    if (document == null) return null;
    return EditorDraft(
      componentsByPage: DesignDocumentCodec.parseDocument(document),
      theme: DesignDocumentCodec.themeOf(document),
      savedAt: DateTime(2026, 1, 1),
      pageRevisions: DesignDocumentMeta.pageRevisions(document),
    );
  }

  @override
  Future<PageSaveResult> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
    Map<String, int> knownRevisions = const {},
    bool force = false,
  }) async {
    final savedRevisions = <String, int>{};
    for (final entry in componentsByPage.entries) {
      final revision = server.savePage(
        entry.key,
        entry.value,
        theme: theme,
        expectedRevision: knownRevisions[entry.key] ?? 0,
        force: force,
      );
      savedRevisions[entry.key] = revision;
    }
    return PageSaveResult(
      savedRevisions: savedRevisions,
      savedAt: DateTime(2026, 1, 2),
    );
  }

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
    String? name,
    String? note,
  }) async {
    server.publishWholeDocument(designDocument);
    return _versionInfo(server.versionRows.last);
  }

  @override
  Future<PublishedVersionInfo> publishPages({
    required Set<String> pageIds,
    Map<String, int> knownRevisions = const {},
    bool force = false,
    String? name,
    String? note,
  }) async {
    server.publishPages(
      pageIds,
      expectedRevisions: force
          ? const {}
          : {
              for (final pageId in pageIds)
                pageId: knownRevisions[pageId] ?? 0,
            },
      name: name,
      note: note,
    );
    return _versionInfo(server.versionRows.last);
  }

  PublishedVersionInfo _versionInfo(Map<String, dynamic> row) =>
      PublishedVersionInfo(
        id: row['id'] as String,
        versionNumber: row['version_number'] as int,
        publishedAt: DateTime(2026, 1, 3),
        schemaVersion: 2,
        name: row['name'] as String?,
        note: row['note'] as String?,
      );

  @override
  Future<List<PublishedVersionInfo>> listVersions({int limit = 30}) async => [
    for (final row in server.versionRows.reversed)
      PublishedVersionInfo(
        id: row['id'] as String,
        versionNumber: row['version_number'] as int,
        publishedAt: DateTime(2026, 1, 3),
        schemaVersion: 2,
        name: row['name'] as String?,
        note: row['note'] as String?,
      ),
  ];

  @override
  Future<Map<String, dynamic>?> getVersionDocument(String versionId) async {
    for (final row in server.versionRows) {
      if (row['id'] == versionId) {
        return Map<String, dynamic>.from(row['document'] as Map);
      }
    }
    return null;
  }

  @override
  Future<PublishedVersionInfo> restoreVersion(String versionId) async {
    final document = await getVersionDocument(versionId);
    if (document == null) throw StateError('الإصدار غير موجود');
    server.publishWholeDocument(document);
    return _versionInfo(server.versionRows.last);
  }

  @override
  Future<void> discardDraft() async => server.draft = null;

  // ---- القوالب (228) ----

  final Map<String, Map<String, dynamic>> _templateDocuments = {};

  @override
  Future<Map<String, dynamic>?> getTemplateDocument(String templateId) async {
    final document = _templateDocuments[templateId];
    if (document == null) return null;
    return Map<String, dynamic>.from(document);
  }

  @override
  Future<List<DesignTemplateInfo>> listTemplates() async => const [];

  @override
  Future<DesignTemplateInfo> saveTemplate({
    String? id,
    required String name,
    required Map<String, dynamic> document,
  }) async {
    final templateId = id ?? 'template-1';
    _templateDocuments[templateId] = document;
    return DesignTemplateInfo(
      id: templateId,
      name: name,
      schemaVersion: 2,
      updatedAt: DateTime(2026, 1, 3),
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) async {}
}

/// محرّر جلسة كامل فوق الخادم المشترك.
VisualEditorCubit _session(
  _ServerDesignStore server, {
  _ServerBackedRepository? repository,
}) => VisualEditorCubit(
  repository: repository ?? _ServerBackedRepository(server),
);

/// بذرة مستند يحتوي صفحة واحدة مكونة من عنصر واحد بخصيصة نصية مميزة.
Map<String, dynamic> _seedDocument({
  required String pageId,
  required String componentId,
  required String propertyKey,
  required String propertyValue,
}) => DesignDocumentMeta.withPageRevision(DesignDocumentCodec.document(
  {
    pageId: [
      EditableComponent(
        componentId: componentId,
        pageId: pageId,
        componentType: 'heading',
        index: 0,
        classification: ComponentClassification.editable,
        properties: {propertyKey: propertyValue},
        defaultValues: const {},
        validationRules: const {},
        allowedOperations: const ['edit'],
        version: 1,
      ),
    ],
  },
), pageId, 1);

/// بذرة مستند بمراجعات مُعتمدة كما يخرج من حفظ حقيقي.
Map<String, dynamic> _seedRevisions(
  Map<String, dynamic> document,
  Map<String, int> revisions,
) {
  var seeded = document;
  revisions.forEach((page, revision) {
    seeded = DesignDocumentMeta.withPageRevision(seeded, page, revision);
  });
  return seeded;
}

EditableComponent _heading(
  String pageId,
  String componentId,
  String propertyValue,
) => EditableComponent(
  componentId: componentId,
  pageId: pageId,
  componentType: 'heading',
  index: 0,
  classification: ComponentClassification.editable,
  properties: {'text': propertyValue},
  defaultValues: const {},
  validationRules: const {},
  allowedOperations: const ['edit'],
  version: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ComponentRegistry.initialize();
  ComponentRegistry.all.forEach(DesignDocumentCodec.registerEntry);

  test('حفظ صفحتين بالتبادل لا يفقد تعديلات أيٍّ منهما', () async {
    final server = _ServerDesignStore()
      ..draft = _seedDocument(
        pageId: 'home',
        componentId: 'home_1',
        propertyKey: 'text',
        propertyValue: 'base',
      );
    final sessionA = _session(server);
    final sessionB = _session(server);
    addTearDown(sessionA.close);
    addTearDown(sessionB.close);
    await sessionA.initialize();
    await sessionB.initialize();

    // جلسة A تعدّ الرئيسية وتحفظ (مراجعة 2 للرئيسية).
    sessionA.addComponent(pageId: 'home', componentType: 'productGrid');
    await sessionA.saveDraft();
    expect(_ServerDesignStore._revisionOf(server.draft, 'home'), 2);

    // جلسة B عدّلت السلة قبل وبعد حفظ A — حفظها يدمج السلة وحدها
    // ولا يمس مراجعة الرئيسية ولا عناصرها.
    sessionB.addComponent(pageId: 'cart', componentType: 'heading');
    await sessionB.saveDraft();
    expect(_ServerDesignStore._revisionOf(server.draft, 'home'), 2);
    expect(_ServerDesignStore._revisionOf(server.draft, 'cart'), 1);

    // A تعدّ الرئيسية مرة أخرى وتحفظ: تعديلات B في السلة تبقى.
    sessionA.addComponent(pageId: 'home', componentType: 'bundleList');
    await sessionA.saveDraft();
    final cartPage = DesignDocumentCodec.parseDocument(server.draft!)['cart']!;
    expect(cartPage.any((node) => node.componentType == 'heading'), isTrue);
    final homePage = DesignDocumentCodec.parseDocument(server.draft!)['home']!;
    expect(homePage.length, greaterThanOrEqualTo(3));
  });

  test('تعديل نفس الصفحة من جلستين متزامنتين يرفع تعارضًا ولا يكتب فوق أحدث',
      () async {
    final server = _ServerDesignStore()
      ..draft = _seedDocument(
        pageId: 'home',
        componentId: 'home_1',
        propertyKey: 'text',
        propertyValue: 'base',
      );
    final sessionA = _session(server);
    final sessionB = _session(server);
    addTearDown(sessionA.close);
    addTearDown(sessionB.close);
    await sessionA.initialize();
    await sessionB.initialize();

    // الجلستان تحمّلان المراجعة 1 معًا.
    expect(sessionA.state.isDirty, isFalse);
    sessionA.addComponent(pageId: 'home', componentType: 'productGrid');
    final saved = await sessionA.saveDraft();
    expect(saved, {'home'});
    // القاعدة الآن مراجعة 2 للرئيسية؛ B ما زالت مرجعها 1.

    sessionB.addComponent(pageId: 'home', componentType: 'bundleList');
    final savedB = await sessionB.saveDraft();
    expect(savedB, isEmpty, reason: 'حفظ B يُرفض بالتعارض');
    expect(
      sessionB.state.conflict,
      isNotNull,
      reason: 'حالة B تحمل تعارضًا لقرار الموظف',
    );
    expect(sessionB.state.conflict!.serverRevision, 2);
    expect(sessionB.state.conflict!.knownRevision, 1);
    // تعديل B المحلي محفوظ في الحالة (لا فقد صامت) والمسودة لم تتغير.
    expect(sessionB.state.isDirty, isTrue);
    expect(_ServerDesignStore._revisionOf(server.draft, 'home'), 2);

    // قرار الموظف: إجبار الحفظ — يكتب نسخته فوق المراجعة الأحدث صراحة.
    await sessionB.forceSaveConflicted();
    expect(_ServerDesignStore._revisionOf(server.draft, 'home'), 3);
    expect(sessionB.state.conflict, isNull);
  });

  test('الكتابة القديمة فوق مراجعة أحدث تُرفض والمستند لا يتغير', () async {
    final server = _ServerDesignStore()
      ..draft = _seedDocument(
        pageId: 'home',
        componentId: 'home_1',
        propertyKey: 'text',
        propertyValue: 'base',
      );
    final repository = _ServerBackedRepository(server);
    // مراجعة القاعدة الحالية: 1. عميل يعرف المراجعة 1 لكن قاعدة تحمل 2:
    server.savePage(
      'home',
      [_heading('home', 'home_1', 'other-session')],
      theme: DesignTheme.none,
      expectedRevision: 1,
      force: true,
    );
    final draftBefore = Map<String, dynamic>.from(server.draft!);

    await expectLater(
      repository.saveDraft(
        {
          'home': [_heading('home', 'home_1', 'stale-client')],
        },
        knownRevisions: {'home': 1},
      ),
      throwsA(isA<PageRevisionConflict>()),
    );
    expect(
      server.draft,
      equals(draftBefore),
      reason: 'الرفض يعني صفر كتابة: مستند المسودة كما كان حرفيًا',
    );
    final home = DesignDocumentCodec.parseDocument(server.draft!)['home']!;
    expect(
      home.first.properties['text'],
      'other-session',
      reason: 'تعديل الجلسة الأحدث هو الباقي',
    );
  });

  test('نشر Home فقط يعتمد الرئيسية ويحفظ آخر منشور لبقية الصفحات',
      () async {
    final server = _ServerDesignStore()
      // منشور سابق: رئيسية قديمة + سلة منشورة قديمة.
      ..published = DesignDocumentCodec.document(
        {
          'home': [_heading('home', 'home_old', 'home-published-v1')],
          'cart': [_heading('cart', 'cart_pub', 'cart-published-v1')],
        },
      )
      // مسودة: رئيسية أحدث (مراجعة 5) + سلة أحدث (مراجعة 3) لم تُعتمد بعد.
      ..draft = _seedRevisions(
        DesignDocumentCodec.document(
          {
            'home': [_heading('home', 'home_new', 'home-draft-v2')],
            'cart': [_heading('cart', 'cart_draft', 'cart-draft-v2')],
          },
        ),
        {'home': 5, 'cart': 3},
      );

    final repository = _ServerBackedRepository(server);
    final revisions = DesignDocumentMeta.pageRevisions(server.draft!);
    await repository.publishPages(
      pageIds: {'home'},
      knownRevisions: revisions,
      name: 'نشر الرئيسية',
    );

    final published = server.published!;
    final publishedHome =
        DesignDocumentCodec.parseDocument(published)['home']!;
    final publishedCart = DesignDocumentCodec.parseDocument(published)['cart']!;
    expect(
      publishedHome.first.properties['text'],
      'home-draft-v2',
      reason: 'الرئيسية المنشورة هي أحدث مسودة',
    );
    expect(
      publishedCart.first.properties['text'],
      'cart-published-v1',
      reason: 'السلة تبقى بآخر منشور لها — مسودتها لا تُنشر تلقائيًا',
    );
    // مراجعة الصفحة المعتمدة تسجَّل من مراجعتها في المسودة.
    expect(
      DesignDocumentMeta.pageRevision(published, 'home'),
      revisions['home'],
    );
  });

  test('مسودات الصفحات الأخرى تبقى سليمة بعد نشر صفحة واحدة', () async {
    final server = _ServerDesignStore()
      ..draft = _seedRevisions(
        DesignDocumentCodec.document(
          {
            'home': [_heading('home', 'home_1', 'home-draft')],
            'splash': [
              EditableComponent(
                componentId: 'splash_1',
                pageId: 'splash',
                componentType: 'splashSettings',
                index: 0,
                classification: ComponentClassification.editable,
                properties: {'text': 'splash-draft'},
                defaultValues: const {},
                validationRules: const {},
                allowedOperations: const ['edit'],
                version: 1,
              ),
            ],
            'cart': [_heading('cart', 'cart_1', 'cart-draft')],
          },
        ),
        {'home': 5, 'splash': 2, 'cart': 1},
      );
    final draftBefore = Map<String, dynamic>.from(server.draft!);
    final repository = _ServerBackedRepository(server);
    final revisions = DesignDocumentMeta.pageRevisions(server.draft!);

    await repository.publishPages(
      pageIds: {'home'},
      knownRevisions: revisions,
    );

    expect(
      server.draft,
      equals(draftBefore),
      reason: 'النشر يعتمد صفحة ولا يلمس المسودة إطلاقًا',
    );
    final splash = DesignDocumentCodec.parseDocument(server.draft!)['splash']!;
    expect(splash, hasLength(1));
    expect(splash.first.properties['text'], 'splash-draft');
  });

  test('نسخة جديدة من أحدث Draft ولا نسخة سابقة تُمسّ', () async {
    final server = _ServerDesignStore()
      ..draft = DesignDocumentCodec.document(
        {
          'home': [_heading('home', 'home_1', 'home-v2')],
        },
      );
    final repository = _ServerBackedRepository(server);
    final revisions = DesignDocumentMeta.pageRevisions(server.draft!);

    // أول نشر (نسخة 1).
    final first = await repository.publishPages(
      pageIds: {'home'},
      knownRevisions: revisions,
    );
    expect(first.versionNumber, 1);
    final firstRow = Map<String, dynamic>.from(server.versionRows.first);

    // تعديل المسودة ثم نشر ثانٍ (نسخة 2).
    server.savePage(
      'home',
      [_heading('home', 'home_1', 'home-v3')],
      theme: DesignTheme.none,
      expectedRevision: revisions['home'] ?? 0,
      force: true,
    );
    final freshRevisions = DesignDocumentMeta.pageRevisions(server.draft!);
    final second = await repository.publishPages(
      pageIds: {'home'},
      knownRevisions: freshRevisions,
    );
    expect(second.versionNumber, 2);

    // النسخة الأولى كما هي حرفيًا (غير قابلة للتعديل)، والثانية تحمل
    // أحدث مسودة، والمنشور صار النسخة الثانية.
    expect(server.versionRows.first, equals(firstRow));
    final secondDocument = DesignDocumentCodec.parseDocument(
      server.versionRows.last['document'] as Map,
    )['home']!;
    expect(secondDocument.first.properties['text'], 'home-v3');
    final publishedHome = DesignDocumentCodec.parseDocument(
      server.published!,
    )['home']!;
    expect(publishedHome.first.properties['text'], 'home-v3');
    final versions = await repository.listVersions();
    expect(versions, hasLength(2));
    expect(versions.first.versionNumber, 2);
    expect(versions.last.versionNumber, 1);
  });

  test('إجبار النشر بعد تعارض يعتمد أحدث مسودة فعلية من القاعدة', () async {
    final server = _ServerDesignStore()
      ..draft = DesignDocumentCodec.document(
        {
          'home': [_heading('home', 'home_1', 'mine')],
        },
      );
    final sessionA = _session(server);
    final sessionB = _session(server);
    addTearDown(sessionA.close);
    addTearDown(sessionB.close);
    await sessionA.initialize();
    await sessionB.initialize();

    sessionA.addComponent(pageId: 'home', componentType: 'productGrid');
    await sessionA.saveDraft();

    sessionB.addComponent(pageId: 'home', componentType: 'bundleList');
    await sessionB.publish(name: 'v-b');
    expect(sessionB.state.conflict, isNotNull);
    // قرار الموظف: حمّل نسخة القاعدة ثم انشر — لا اعتماد لأشياء لم يرها.
    await sessionB.reloadConflictedFromServer();
    expect(sessionB.state.conflict, isNull);
    final version = await sessionB.publish(name: 'v-b2');
    expect(version, isNotNull);
    final publishedHome = DesignDocumentCodec.parseDocument(
      server.published!,
    )['home']!;
    // النشر اعتمد أحدث مسودة محفوظة (نسخة A) لا نسخة B المحلية.
    expect(
      publishedHome.any(
        (component) => component.componentType == 'productGrid',
      ),
      isTrue,
    );
    expect(
      publishedHome.any(
        (component) => component.componentType == 'bundleList',
      ),
      isFalse,
    );
  });

  test('إفراغ صفحة من مكوّناتها يزيلها من المسودة دون إعادة الصفحات الأخرى',
      () async {
    final server = _ServerDesignStore()
      ..draft = _seedRevisions(
        DesignDocumentCodec.document(
          {
            'home': [_heading('home', 'home_1', 'home')],
            'cart': [_heading('cart', 'cart_1', 'cart')],
          },
        ),
        {'cart': 4},
      );
    final repository = _ServerBackedRepository(server);
    final revisions = DesignDocumentMeta.pageRevisions(server.draft!);

    // حذف صريح: إزالة كل عناصر السلة (تسقط من المستند مطابقة لسلوك
    // document()) — الرئيسية لا تُمسّ.
    final revision = await repository.saveDraft(
      {
        'cart': const [],
      },
      knownRevisions: revisions,
    );
    expect(revision.savedRevisions['cart'], revisions['cart']! + 1);
    final pages = DesignDocumentCodec.parseDocument(server.draft!);
    expect(pages.containsKey('cart'), isFalse);
    expect(pages['home']!.first.properties['text'], 'home');
  });

  test('تطبيق قالب لا يحذف الصفحات الغائبة عنه', () async {
    final server = _ServerDesignStore()
      ..draft = _seedRevisions(
        DesignDocumentCodec.document(
          {
            'home': [_heading('home', 'home_1', 'home-current')],
            'splash': [
              EditableComponent(
                componentId: 'splash_1',
                pageId: 'splash',
                componentType: 'splashSettings',
                index: 0,
                classification: ComponentClassification.editable,
                properties: {'text': 'splash-current'},
                defaultValues: const {},
                validationRules: const {},
                allowedOperations: const ['edit'],
                version: 1,
              ),
            ],
          },
        ),
        {'home': 2, 'splash': 1},
      );
    final repository = _ServerBackedRepository(server);
    final session = _session(server, repository: repository);
    addTearDown(session.close);
    await session.initialize();

    // قالب يغطي الرئيسية فقط — لا يحتوي السبلاش.
    await repository.saveTemplate(
      id: 'tpl-1',
      name: 'قالب رئيسية',
      document: _seedRevisions(
        DesignDocumentCodec.document(
          {
            'home': [_heading('home', 'home_tpl', 'home-from-template')],
          },
        ),
        {'home': 9},
      ),
    );

    final applied = await session.applyTemplate('tpl-1');
    expect(applied, isTrue);
    final home = session.state.getComponentsForPage('home');
    expect(
      home.firstWhere((c) => c.componentId == 'home_tpl').properties['text'],
      'home-from-template',
    );
    final splash = session.state.getComponentsForPage('splash');
    expect(splash, hasLength(1));
    expect(splash.first.properties['text'], 'splash-current');

    // حفظ بعد القالب: الصفحتان معًا تُدمجان — لا تعود السبلاش للافتراضي.
    await session.saveDraft();
    final draftPages = DesignDocumentCodec.parseDocument(server.draft!);
    expect(draftPages['splash']!.first.properties['text'], 'splash-current');
    expect(
      draftPages['home']!.firstWhere(
        (c) => c.componentId == 'home_tpl',
      ).properties['text'],
      'home-from-template',
    );
  });
}
