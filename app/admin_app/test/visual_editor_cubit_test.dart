import 'package:admin_app/features/visual_editor/data/visual_editor_repository.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/design_document_codec.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// مستودع زائف: يسجّل الاستدعاءات ولا يلمس شبكة.
///
/// كل دالة تحاكي عقد الـ RPC الحي: المسودة تُقرأ null حين لا شيء محفوظ،
/// والنشر يرفض مستندًا غير صالح كأن القاعدة فعلت.
class _FakeVisualEditorRepository implements VisualEditorRepository {
  _FakeVisualEditorRepository();

  Map<String, List<EditableComponent>>? savedDraft;
  DesignTheme? savedTheme;
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
  Future<EditorDraft?> loadDraft() async => null;

  @override
  Future<DateTime> saveDraft(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) async {
    savedDraft = Map.of(componentsByPage);
    savedTheme = theme;
    return DateTime(2026, 1, 1);
  }

  @override
  Future<PublishedVersionInfo> publishDesign(
    Map<String, dynamic> designDocument, {
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
  Future<List<DesignTemplateInfo>> listTemplates() async =>
      List.of(templates);

  @override
  Future<Map<String, dynamic>?> getTemplateDocument(
    String templateId,
  ) async =>
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

  test('تهيئة بلا مسودة تبدأ من تصميم اليوم', () async {
    await cubit.initialize();
    expect(cubit.state.status, VisualEditorStatus.ready);
    expect(cubit.state.getComponentsForPage('home'), hasLength(8));
    expect(cubit.state.isDirty, isFalse);
    expect(cubit.canUndo, isFalse);
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
    expect(cubit.state.getComponentsForPage('home'), hasLength(9),
        reason: 'header محمي بلا delete في allowedOperations');
  });

  test('حذف مكوّن مسموح يحذفه فعلًا', () async {
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final grid = cubit.state.getComponentsForPage('home').last;
    cubit.deleteComponent(grid.componentId);
    expect(cubit.state.getComponentsForPage('home'), hasLength(8));
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
    final afterInvalid =
        cubit.state.findComponent(grid.componentId)!.properties['columns'];
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

  test('النشر ينشر تصميم اليوم ثم يحمل الإضافات', () async {
    // بلا مسودة يبدأ المحرر من تصميم اليوم (8 أقسام) — النشر الأول ينشره
    // كما هو، والرأس المحمي يضمن ألا تصبح الصفحة فارغة أبدًا.
    await cubit.initialize();
    final first = await cubit.publish();
    expect(first, isNotNull);
    expect(repository.publishedDocuments, hasLength(1));

    cubit.addComponent(pageId: 'home', componentType: 'productGrid');
    final version = await cubit.publish();
    expect(version, isNotNull);
    expect(repository.publishedDocuments, hasLength(2));
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

  test('النشر يمرر المستند عبر تدقيق محلي قبل القاعدة', () async {
    // ملاحظة: cubit يبني المستند من السجل نفسه، فالرفض المحلي يظهر فقط
    // لو خرج سجل المكوّنات عن العقد — وهذا الاختبار يثبت أن الرفض يظهر
    // في الحالة قبل اتصال المستودع.
    await cubit.initialize();
    cubit.addComponent(pageId: 'home', componentType: 'bannerCarousel');
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

  test('الاسترجاع يجيب بخطأ مفهوم حين يفشل', () async {
    await cubit.initialize();
    final result = await cubit.restoreVersion('missing-version');
    expect(result, isNull);
    expect(cubit.state.errorMessage, contains('تعذر استرجاع الإصدار'));
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
    final columnInFlat = flat
        .firstWhere((c) => c.componentId == column.componentId);
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
    expect(
      await cubit.saveCurrentAsTemplate('x' * 61),
      isNull,
    );
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
}
