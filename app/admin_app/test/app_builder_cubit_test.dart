import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_state.dart';

/// قاعدة زائفة للاختبار وحده: تُخزّن في الذاكرة وتعدّ النداءات، فلا مسار قراءة
/// ثاني في التطبيق ولا بيانات وهمية تُعرض على شاشة.
class _FakeRepository implements AppBuilderRepository {
  _FakeRepository({
    this.draft,
    this.published,
    this.versions = const <DesignVersion>[],
    this.failLoad = false,
  });

  DesignDocument? draft;
  DesignDocument? published;
  List<DesignVersion> versions;
  final Map<String, DesignDocument> files = <String, DesignDocument>{};

  int saveCalls = 0;
  int publishCalls = 0;
  int restoreCalls = 0;
  bool failSave = false;
  bool failPublish = false;
  bool failLoad = false;

  @override
  Future<DesignDocument?> loadDraft() async {
    _maybeFail();
    return draft;
  }

  @override
  Future<DesignDocument?> loadPublished() async {
    _maybeFail();
    return published;
  }

  @override
  Future<List<DesignVersion>> loadVersions() async {
    _maybeFail();
    return versions;
  }

  @override
  Future<DesignDocument?> loadVersion(String versionId) async => files[versionId];

  @override
  Future<void> saveDraft(DesignDocument document) async {
    saveCalls++;
    if (failSave) throw StateError('rejected');
    draft = document;
  }

  @override
  Future<DesignVersion> publish(DesignDocument document) async {
    publishCalls++;
    if (failPublish) throw StateError('forbidden');
    published = document;
    draft = document;
    final version = DesignVersion(
      id: 'v${versions.length + 1}',
      number: versions.length + 1,
      publishedAt: DateTime(2026, 11, 3),
      schemaVersion: document.schemaVersion,
    );
    versions = <DesignVersion>[version, ...versions];
    files[version.id] = document;
    return version;
  }

  @override
  Future<DesignVersion> restoreVersion(String versionId) async {
    restoreCalls++;
    final stored = files[versionId];
    if (stored == null) throw StateError('missing version');
    published = stored;
    final version = DesignVersion(
      id: 'restore-$versionId',
      number: versions.length + 1,
      publishedAt: DateTime(2026, 11, 3),
      schemaVersion: stored.schemaVersion,
    );
    versions = <DesignVersion>[version, ...versions];
    return version;
  }

  @override
  Future<void> discardDraft() async => draft = null;

  void _maybeFail() {
    if (failLoad) throw StateError('network');
  }
}

void main() {
  late _FakeRepository repository;
  late AppBuilderCubit cubit;

  Future<AppBuilderCubit> open({
    DesignDocument? draft,
    DesignDocument? published,
    bool failLoad = false,
  }) async {
    repository = _FakeRepository(
      draft: draft,
      published: published,
      failLoad: failLoad,
    );
    cubit = AppBuilderCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  group('القراءة الأولى', () {
    test('لا مسودة ولا منشور: يفتح المحرّر على ترتيب العميل الحالي', () async {
      await open();
      expect(cubit.state.status, AppBuilderStatus.ready);
      expect(
        cubit.state.document?.rootOf(AppPage.home)?.type,
        WidgetTypes.pageHome,
      );
      expect(cubit.state.published, isNull);
      // لا شيء محفوظ بعد، فالشاشة تُخبر الموظف أن عمله لم يصل إلى القاعدة.
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.canUndo, isFalse);
    });

    test('المسودة تسبق المنشور، والمنشور يبقى معلومًا للمقارنة', () async {
      final draft = WidgetRegistry.defaultDocument();
      final published = DesignDocument(
        schemaVersion: draft.schemaVersion,
        pages: <AppPage, DesignNode>{
          AppPage.home: WidgetRegistry.node(WidgetTypes.pageHome, 'home'),
        },
      );
      await open(draft: draft, published: published);

      expect(cubit.state.document, same(draft));
      expect(cubit.state.published, same(published));
      expect(cubit.state.isDirty, isFalse);
    });

    test('فشل القراءة يقلب الحالة كلها إلى فشل ولا يترك شاشة نصف مبنية', () async {
      await open(failLoad: true);
      expect(cubit.state.status, AppBuilderStatus.failure);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.document, isNull);
    });
  });

  group('البناء', () {
    test('الإضافة تحرسها الشرعية، واللوحة تعرف السبب', () async {
      await open();

      final rejected = cubit.insert(
        type: WidgetTypes.header,
        parentId: 'home_search',
      );
      expect(rejected, DesignEditRejection.parentIsNotContainer);
      expect(cubit.state.document?.sectionsOf(AppPage.home).length, 8);

      expect(
        cubit.insert(type: WidgetTypes.divider, parentId: 'home', index: 1),
        DesignEditRejection.none,
      );
      final sections = cubit.state.document!.sectionsOf(AppPage.home);
      expect(sections.length, 9);
      expect(sections[1].type, WidgetTypes.divider);
      expect(cubit.state.selectedId, sections[1].id);
      expect(cubit.state.canUndo, isTrue);
    });

    test('الحذف والإخفاء يتركان الأساس وأبناءه', () async {
      await open();

      expect(
        cubit.remove('home_header'),
        DesignEditRejection.lockedComponent,
      );
      expect(cubit.toggleVisible('home_header'), DesignEditRejection.lockedComponent);
      expect(
        cubit.remove('home'),
        DesignEditRejection.containerNotEmpty,
      );

      expect(cubit.remove('home_banners'), DesignEditRejection.none);
      expect(cubit.state.selectedId, isNull);
      expect(
        cubit.state.document?.sectionsOf(AppPage.home).map((s) => s.id),
        isNot(contains('home_banners')),
      );

      expect(cubit.toggleVisible('home_categories'), DesignEditRejection.none);
      expect(
        DesignTree.find(
          cubit.state.document!.rootOf(AppPage.home)!,
          'home_categories',
        )!.isVisible,
        isFalse,
      );
    });

    test('النقل داخل الصفحة يخضع لنفس الفحص الذي يخضع له الإفلات', () async {
      await open();
      final before = cubit.state.document;

      expect(
        cubit.move(id: 'home_header', newParentId: 'home', index: 3),
        DesignEditRejection.lockedComponent,
      );
      expect(cubit.state.document, same(before));

      expect(
        cubit.move(id: 'home_search', newParentId: 'home_banners', index: 0),
        DesignEditRejection.parentIsNotContainer,
      );

      expect(
        cubit.move(id: 'home_search', newParentId: 'home', index: 0),
        DesignEditRejection.none,
      );
      expect(
        cubit.state.document?.sectionsOf(AppPage.home).first.id,
        'home_search',
      );
    });

    test('التكرار يضع النسخة بجوار الأصل ويحدّدها', () async {
      await open();
      expect(cubit.duplicate('home_banners'), DesignEditRejection.none);

      final sections = cubit.state.document!.sectionsOf(AppPage.home);
      expect(sections.length, 9);
      // النسخة تحمل اسم الأصل لا اسم النوع: سطر واحد في الشجرة، وهو ما يراه
      // الموظف في لوحة الطبقات عند عنصرين من نوع واحد.
      expect(sections[3].id, 'home_banners-2');
      expect(sections[3].type, WidgetTypes.bannerCarousel);
      expect(cubit.state.selectedId, 'home_banners-2');
      expect(cubit.duplicate('home_header'), DesignEditRejection.lockedComponent);
    });

    test('الخاصية لا تمرّ خارج ما يحدّه السجل', () async {
      await open();

      expect(
        cubit.setProperty(id: 'home_banners', key: 'maxItems', value: 99),
        'أكبر من الحدّ',
      );
      expect(
        cubit.setProperty(id: 'home_banners', key: 'invented', value: 1),
        'خاصية لا يعرفها المكوّن',
      );
      expect(
        cubit.setProperty(
          id: 'home_banners',
          key: 'radius',
          value: 'not-a-token',
        ),
        'قيمة غير مسموحة',
      );
      expect(
        cubit.setProperty(id: 'home_banners', key: 'autoplay', value: false),
        isNull,
      );
      expect(
        DesignTree.find(
          cubit.state.document!.rootOf(AppPage.home)!,
          'home_banners',
        )!.boolProperty('autoplay'),
        isFalse,
      );
    });

    test('مصدر بيانات بلا تصنيف مطلوب لا يُنشر، والمسودة تُحفظ رغم ذلك', () async {
      await open();
      cubit.setProperty(
        id: 'home_popular',
        key: 'dataSource',
        value: DataSourceRegistry.categoryProducts,
      );
      cubit.setProperty(id: 'home_popular', key: 'linkLabel', value: '');

      expect(cubit.state.canPublish, isFalse);
      expect(await cubit.publish(), isFalse);
      expect(repository.publishCalls, 0);

      // المسودة لا تُدقَّق: الموظف يبني، والبناء قد يمرّ بلحظة غير مكتملة.
      expect(await cubit.saveDraft(), isTrue);
      expect(cubit.state.isDirty, isFalse);
    });
  });

  group('التراجع', () {
    test('خطوة رجوع ثم إعادة، والتحديد يسقط مع العقدة الزائلة', () async {
      await open();
      cubit.insert(type: WidgetTypes.divider, parentId: 'home', index: 1);
      final added = cubit.state.document;
      final dividerId = cubit.state.selectedId;
      expect(dividerId, isNotNull);

      cubit.undo();
      expect(cubit.state.document?.sectionsOf(AppPage.home).length, 8);
      expect(cubit.state.canUndo, isFalse);
      expect(cubit.state.canRedo, isTrue);
      expect(cubit.state.selectedId, isNull);

      cubit.redo();
      expect(cubit.state.document, same(added));
      expect(cubit.state.selectedId, isNull);
    });

    test('سجل الرجوع له عمق، فلا تكبر الذاكرة مع جلسة طويلة', () async {
      await open();
      for (var i = 0; i < AppBuilderCubit.historyDepth + 12; i++) {
        cubit.setProperty(id: 'home_banners', key: 'maxItems', value: 1 + (i % 20));
      }
      var steps = 0;
      while (cubit.state.canUndo && steps <= AppBuilderCubit.historyDepth + 20) {
        final before = cubit.state.document;
        cubit.undo();
        if (cubit.state.document == before) break;
        steps++;
      }
      expect(steps, lessThanOrEqualTo(AppBuilderCubit.historyDepth));
    });
  });

  group('النشر والإصدارات', () {
    test('نشر صحيح يحدّث المنشور والمصادر ويترك المسودة خلفه', () async {
      await open();
      expect(cubit.state.canPublish, isTrue);

      expect(await cubit.publish(), isTrue);
      expect(repository.publishCalls, 1);
      expect(cubit.state.published, same(cubit.state.document));
      expect(cubit.state.versions.length, 1);
      expect(cubit.state.latestVersion?.number, 1);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.source, AppBuilderSource.published);
    });

    test('رفض القاعدة للنشر يبقى كلامًا على الشاشة لا حالة نصف منشورة', () async {
      await open();
      repository.failPublish = true;

      expect(await cubit.publish(), isFalse);
      expect(cubit.state.published, isNull);
      expect(cubit.state.isPublishing, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('استعراض إصدار يعرض ملفّه في الهاتف دون أن يلمس المسودة', () async {
      await open();
      await cubit.publish();
      final draft = cubit.state.document;
      final versionId = cubit.state.versions.first.id;

      // نسخة قديمة أصغر: جذر رئيسية بلا مقاطع، فتُرى الفرق في المعاينة.
      repository.files[versionId] = DesignDocument(
        schemaVersion: draft!.schemaVersion,
        pages: <AppPage, DesignNode>{
          AppPage.home: WidgetRegistry.node(WidgetTypes.pageHome, 'home', children: <DesignNode>[
            WidgetRegistry.node(WidgetTypes.header, 'home_header'),
          ]),
        },
      );

      await cubit.inspectVersion(versionId);
      expect(cubit.state.source, AppBuilderSource.version);
      expect(cubit.state.root?.children.length, 1);
      expect(cubit.state.document, same(draft));

      cubit.showSource(AppBuilderSource.draft);
      expect(cubit.state.root?.children.length, 8);
    });

    test('الرجوع إصدارًا إعادة نشر برقم جديد، والمسودة تبقى عمل الموظف', () async {
      await open();
      await cubit.publish();
      final versionId = cubit.state.versions.first.id;
      final draft = cubit.state.document;

      cubit.setProperty(id: 'home_banners', key: 'maxItems', value: 3);
      expect(cubit.state.document, isNot(same(draft)));

      expect(await cubit.restoreVersion(versionId), isTrue);
      expect(repository.restoreCalls, 1);
      expect(cubit.state.versions.length, 2);
      expect(cubit.state.source, AppBuilderSource.published);
      // المنشور عاد إلى ملفّ الإصدار، والمسودة ما زالت تعدّل عليها اللوحة.
      expect(cubit.state.published?.rootOf(AppPage.home)?.children.length, 8);
    });

    test('تجاهل المسودة يرجع إلى المنشور ويصفرّ سجل الرجوع', () async {
      final published = WidgetRegistry.defaultDocument();
      await open(draft: null, published: published);
      cubit.remove('home_banners');
      expect(cubit.state.canUndo, isTrue);

      await cubit.discardDraft();
      expect(cubit.state.document?.rootOf(AppPage.home)?.children.length, 8);
      expect(cubit.state.canUndo, isFalse);
      expect(cubit.state.isDirty, isFalse);
      expect(repository.draft, isNull);
    });
  });

  group('وضع المشاهدة', () {
    test('النقر والتنقل يعملان، ولا عملية بناء تمرّ', () async {
      await open();
      cubit.setMode(AppBuilderMode.preview);
      final before = cubit.state.document;
      expect(cubit.state.isPreview, isTrue);

      cubit.select('home_banners');
      expect(cubit.state.selectedId, isNull); // التحديد يخدم اللوحة لا الهاتف.

      expect(
        cubit.insert(type: WidgetTypes.divider),
        DesignEditRejection.previewMode,
      );
      expect(
        cubit.move(id: 'home_search', newParentId: 'home', index: 0),
        DesignEditRejection.previewMode,
      );
      expect(cubit.remove('home_banners'), DesignEditRejection.previewMode);
      expect(cubit.duplicate('home_banners'), DesignEditRejection.previewMode);
      expect(cubit.toggleVisible('home_banners'), DesignEditRejection.previewMode);
      expect(
        cubit.setProperty(id: 'home_banners', key: 'maxItems', value: 4),
        'قراءة فقط',
      );
      expect(cubit.state.document, same(before));
    });

    test('تبديل الصفحة ينقل التحديد معه، والصفحة المقفلة لا شجرة لها', () async {
      await open();
      cubit.select('home_banners');
      cubit.openPage(AppPage.categories);
      expect(cubit.state.page, AppPage.categories);
      expect(cubit.state.selectedId, isNull);
      expect(cubit.state.root?.type, WidgetTypes.pageCategories);

      cubit.openPage(AppPage.cart);
      expect(cubit.state.root, isNull);
      expect(AppPage.cart.isEditable, isFalse);
    });
  });
}
