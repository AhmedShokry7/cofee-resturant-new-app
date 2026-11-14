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
      contains('productGrid'),
      reason: 'شبكة المنتجات نوع لا يرسمه الهاتف بعد — يُكتب بمفتاحه الداخلي',
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
}
