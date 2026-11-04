import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_template.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_theme.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_version.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/template_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_registry.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/app_builder_repository.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_tree.dart';
import 'package:admin_app/features/customer_preview/domain/services/design_validator.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/app_builder_state.dart';

/// قاعدة زائفة للاختبار وحده: تُخزّن في الذاكرة وتعدّ النداءات، فلا مسار قراءة
/// ثاني في التطبيق ولا بيانات وهمية تُعرض على شاشة.
class _FakeRepository implements AppBuilderRepository {
  _FakeRepository({this.draft, this.published, this.failLoad = false});

  DesignDocument? draft;
  DesignDocument? published;
  List<DesignVersion> versions = <DesignVersion>[];
  final Map<String, DesignDocument> files = <String, DesignDocument>{};

  int saveCalls = 0;
  int publishCalls = 0;
  int restoreCalls = 0;
  bool failSave = false;

  /// ما حفظه الموظف في المعرض: صفوف باسمها وملفّاتها في الذاكرة.
  List<DesignTemplate> templates = <DesignTemplate>[];
  final Map<String, DesignDocument> templateFiles =
      <String, DesignDocument>{};

  int templateSaveCalls = 0;
  int templateDeleteCalls = 0;
  bool failTemplates = false;
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
  Future<DesignDocument?> loadVersion(String versionId) async =>
      files[versionId];

  @override
  Future<List<DesignTemplate>> loadTemplates() async {
    _maybeFail();
    if (failTemplates) throw StateError('templates unavailable');
    return templates;
  }

  @override
  Future<DesignDocument?> loadTemplate(String id) async => templateFiles[id];

  @override
  Future<DesignTemplate> saveTemplate(
    String name,
    DesignDocument document, {
    String? templateId,
  }) async {
    templateSaveCalls++;
    if (failSave) throw StateError('rejected');
    final id = templateId ?? 't${templates.length + 1}';
    final template = DesignTemplate(
      id: id,
      name: name,
      schemaVersion: document.schemaVersion,
      updatedAt: DateTime(2026, 11, 4, 9),
    );
    templateFiles[id] = document;
    templates = <DesignTemplate>[
      template,
      ...templates.where((other) => other.id != id),
    ];
    return template;
  }

  @override
  Future<void> deleteTemplate(String id) async {
    templateDeleteCalls++;
    if (failTemplates) throw StateError('templates unavailable');
    templates = templates.where((template) => template.id != id).toList();
    templateFiles.remove(id);
  }

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

    test(
      'فشل القراءة يقلب الحالة كلها إلى فشل ولا يترك شاشة نصف مبنية',
      () async {
        await open(failLoad: true);
        expect(cubit.state.status, AppBuilderStatus.failure);
        expect(cubit.state.errorMessage, isNotNull);
        expect(cubit.state.document, isNull);
      },
    );
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

      expect(cubit.remove('home_header'), DesignEditRejection.lockedComponent);
      expect(
        cubit.toggleVisible('home_header'),
        DesignEditRejection.lockedComponent,
      );
      expect(cubit.remove('home'), DesignEditRejection.containerNotEmpty);

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
      expect(
        cubit.duplicate('home_header'),
        DesignEditRejection.lockedComponent,
      );
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

    test(
      'مصدر بيانات بلا تصنيف مطلوب لا يُنشر، والمسودة تُحفظ رغم ذلك',
      () async {
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
      },
    );
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
        cubit.setProperty(
          id: 'home_banners',
          key: 'maxItems',
          value: 1 + (i % 20),
        );
      }
      var steps = 0;
      while (cubit.state.canUndo &&
          steps <= AppBuilderCubit.historyDepth + 20) {
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

    test(
      'رفض القاعدة للنشر يبقى كلامًا على الشاشة لا حالة نصف منشورة',
      () async {
        await open();
        repository.failPublish = true;

        expect(await cubit.publish(), isFalse);
        expect(cubit.state.published, isNull);
        expect(cubit.state.isPublishing, isFalse);
        expect(cubit.state.errorMessage, isNotNull);
      },
    );

    test('استعراض إصدار يعرض ملفّه في الهاتف دون أن يلمس المسودة', () async {
      await open();
      await cubit.publish();
      final draft = cubit.state.document;
      final versionId = cubit.state.versions.first.id;

      // نسخة قديمة أصغر: جذر رئيسية بلا مقاطع، فتُرى الفرق في المعاينة.
      repository.files[versionId] = DesignDocument(
        schemaVersion: draft!.schemaVersion,
        pages: <AppPage, DesignNode>{
          AppPage.home: WidgetRegistry.node(
            WidgetTypes.pageHome,
            'home',
            children: <DesignNode>[
              WidgetRegistry.node(WidgetTypes.header, 'home_header'),
            ],
          ),
        },
      );

      await cubit.inspectVersion(versionId);
      expect(cubit.state.source, AppBuilderSource.version);
      expect(cubit.state.root?.children.length, 1);
      expect(cubit.state.document, same(draft));

      cubit.showSource(AppBuilderSource.draft);
      expect(cubit.state.root?.children.length, 8);
    });

    test(
      'الرجوع إصدارًا إعادة نشر برقم جديد، والمسودة تبقى عمل الموظف',
      () async {
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
      },
    );

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
      expect(
        cubit.toggleVisible('home_banners'),
        DesignEditRejection.previewMode,
      );
      expect(
        cubit.setProperty(id: 'home_banners', key: 'maxItems', value: 4),
        'قراءة فقط',
      );
      expect(cubit.state.document, same(before));
    });

    test(
      'تبديل الصفحة ينقل التحديد معه، والصفحة المقفلة لا شجرة لها',
      () async {
        await open();
        cubit.select('home_banners');
        cubit.openPage(AppPage.categories);
        expect(cubit.state.page, AppPage.categories);
        expect(cubit.state.selectedId, isNull);
        expect(cubit.state.root?.type, WidgetTypes.pageCategories);

        cubit.openPage(AppPage.cart);
        expect(cubit.state.root, isNull);
        expect(AppPage.cart.isEditable, isFalse);
      },
    );
  });

  group('طبقة الشكل في اللوحة', () {
    test('اللون يغيّر الشكل وحده، والشجرة تبقى كما كُتبت', () async {
      await open();
      final before = cubit.state.document!;

      expect(cubit.setThemeColor(DesignColorRole.primary, '#c09060'), isNull);
      final after = cubit.state.document!;
      expect(after.theme.colors[DesignColorRole.primary], '#C09060');
      expect(after.rootOf(AppPage.home)?.toMap(), before.rootOf(AppPage.home)?.toMap());
      expect(after.pages.keys, before.pages.keys);

      // الطبقة جزء من المستند، فهي تعدّل وتُحفظ وتُرجع بصفتها مستندًا لا
      // إعدادًا جانبيًا لا يعرف أحد أنه تغيّر.
      expect(cubit.state.canUndo, isTrue);
      expect(cubit.state.isDirty, isTrue);

      cubit.undo();
      expect(cubit.state.document!.theme.isDefault, isTrue);
      expect(cubit.state.canRedo, isTrue);
      cubit.redo();
      expect(cubit.state.document!.theme.colors[DesignColorRole.primary], '#C09060');
    });

    test('القيمة المرفوضة لا تدخل سجل الرجوع', () async {
      await open();
      final before = cubit.state.document;

      expect(cubit.setThemeColor(DesignColorRole.primary, '#GG'), isNotNull);
      expect(cubit.setThemeColor(DesignColorRole.primary, 'red'), isNotNull);
      expect(cubit.setThemeColor(DesignColorRole.primary, 'C09060'), isNotNull);
      expect(cubit.setThemeTextScale('huge'), isNotNull);
      expect(cubit.setThemeRadiusScale('round'), isNull);
      expect(cubit.setThemeTextScale('large'), isNull);

      expect(cubit.state.document, isNot(same(before)));
      expect(cubit.state.document!.theme.colors, isEmpty);
      expect(cubit.state.document!.theme.textScale, 'large');
      expect(cubit.state.document!.theme.radiusScale, 'round');
    });

    test('حذف الدور يرجعه إلى قيمة العميل لا إلى لون من عند اللوحة', () async {
      await open();
      cubit.setThemeColor(DesignColorRole.background, '#FFFFFF');
      cubit.setThemeColor(DesignColorRole.primary, '#C09060');
      final themed = cubit.state.document!;

      cubit.clearThemeColor(DesignColorRole.background);
      expect(cubit.state.document!.theme.colors.keys,
          <DesignColorRole>[DesignColorRole.primary]);

      // دور لم يُلْمَس أصلاً: لا طبقة جديدة، فلا سجل رجوع بعِدلٍ لا معنى له.
      final untouched = cubit.state.document;
      cubit.clearThemeColor(DesignColorRole.success);
      expect(cubit.state.document, same(untouched));

      cubit.clearThemeColor(DesignColorRole.primary);
      expect(cubit.state.document!.theme.isDefault, isTrue);
      expect(cubit.state.document!.toMap().containsKey('theme'), isFalse);
      expect(themed.theme.isChanged, isTrue);
    });

    test('الطبقة تُحفظ مع المسودة وتُنشر مع المستند', () async {
      await open();
      cubit.setThemeColor(DesignColorRole.primary, '#C09060');
      cubit.setThemeTextScale('comfortable');

      expect(await cubit.saveDraft(), isTrue);
      expect(repository.draft?.theme.colors[DesignColorRole.primary], '#C09060');
      expect(repository.draft?.theme.textScale, 'comfortable');

      expect(cubit.state.canPublish, isTrue);
      expect(await cubit.publish(), isTrue);
      expect(repository.published?.theme.toMap(),
          cubit.state.document!.theme.toMap());
      // الرجوع إلى المنشور يمسح الطبقة المخزنة، لا التخطيط وحده.
      cubit.setThemeColor(DesignColorRole.primary, '#000000');
      await cubit.discardDraft();
      expect(cubit.state.document!.theme.colors[DesignColorRole.primary],
          '#C09060');
    });

    test('نص بلون الخلفية يمنع النشر قبل جولة الشبكة', () async {
      await open();
      cubit.setThemeColor(DesignColorRole.textPrimary, '#FFFFFF');
      cubit.setThemeColor(DesignColorRole.background, '#ffffff');

      expect(
        cubit.state.validation?.issues.map((issue) => issue.code),
        contains(DesignIssueCode.themeTextOnSameBackground),
      );
      expect(cubit.state.canPublish, isFalse);
      expect(await cubit.publish(), isFalse);
      expect(repository.publishCalls, 0);
      // المسودة تُقبل: الموظف يلوّن وقد يمرّ بلحظة لا تُقرأ فيها الشاشة.
      expect(await cubit.saveDraft(), isTrue);
    });

    test('الرجوع للتصميم الأصلي يمسح الطبقة في خطوة واحدة', () async {
      await open();
      cubit.setThemeColor(DesignColorRole.primary, '#C09060');
      cubit.setThemeColor(DesignColorRole.border, '#DDDDDD');
      cubit.setThemeTextScale('large');
      final themed = cubit.state.document!;

      cubit.clearTheme();
      expect(cubit.state.document!.theme.isDefault, isTrue);
      expect(cubit.state.document!.toMap().containsKey('theme'), isFalse);

      // خطوة تراجع واحدة، لا ثلاث: الزرّ يَعِدُ بالرجوع لا بإلغاء آخر نقرة.
      cubit.undo();
      expect(sameTheme(cubit.state.document!.theme, themed.theme), isTrue);
      expect(cubit.state.document!.theme.colors[DesignColorRole.border],
          '#DDDDDD');
      expect(cubit.state.document!.theme.textScale, 'large');
      cubit.redo();
      expect(cubit.state.document!.theme.isDefault, isTrue);

      // طبقة محايدة أصلًا: لا عدل ولا سجلّ على ما لا فرق فيه.
      final neutral = cubit.state.document;
      cubit.clearTheme();
      expect(cubit.state.document, same(neutral));
      expect(cubit.state.canRedo, isFalse);
    });

    test('وضع المشاهدة لا يمسح الطبقة', () async {
      await open();
      cubit.setThemeColor(DesignColorRole.primary, '#C09060');
      cubit.setMode(AppBuilderMode.preview);
      final themed = cubit.state.document!;

      cubit.clearTheme();
      expect(cubit.state.document, same(themed));
      expect(cubit.state.document!.theme.colors[DesignColorRole.primary],
          '#C09060');
      expect(themed.theme.isChanged, isTrue);
    });

    test('وضع المشاهدة لا يلوّن', () async {
      await open();
      cubit.setMode(AppBuilderMode.preview);
      final before = cubit.state.document;

      expect(
        cubit.setThemeColor(DesignColorRole.primary, '#C09060'),
        'قراءة فقط',
      );
      expect(cubit.setThemeTextScale('large'), 'قراءة فقط');
      expect(cubit.setThemeRadiusScale('pill'), 'قراءة فقط');
      cubit.clearThemeColor(DesignColorRole.primary);
      expect(cubit.state.document, same(before));
      expect(cubit.state.canUndo, isFalse);
    });
  });

  group('القوالب', () {
    test('تطبيق قالب مضمّن يعدّل المسودة ولا ينشر شيئًا', () async {
      await open();
      final before = cubit.state.document!;

      cubit.applyBuiltInTemplate(TemplateRegistry.quickOrder);
      final after = cubit.state.document!;

      // الترتيب وصل إلى المستند نفسه، فهو ما يُحفظ وما يُنشر لاحقًا.
      expect(after.sectionsOf(AppPage.home).first.id, 'home_search');
      expect(after.hasSameContent(before), isFalse);
      expect(cubit.state.canUndo, isTrue);
      expect(cubit.state.isDirty, isTrue);
      // لا نشر ضمني: الزبون لا يرى ترتيبًا لم يوافق عليه الموظف بعد.
      expect(repository.publishCalls, 0);
      expect(repository.published, isNull);

      cubit.undo();
      expect(
        cubit.state.document!.sectionsOf(AppPage.home).first.id,
        'home_header',
      );
    });

    test('قالب اليوم لا يحرّك مستندًا لم يلمسه الموظف', () async {
      await open();
      final before = cubit.state.document!;

      cubit.applyBuiltInTemplate(TemplateRegistry.today);
      // عملية لم تغيّر حرفًا لا تدخل طابور التراجع، ولا تبدّل كائن المستند.
      expect(cubit.state.document, same(before));
      expect(cubit.state.canUndo, isFalse);
    });

    test('حفظ المسودة كقالب يضيفها إلى اللوحة ثم يفتحها منها', () async {
      await open();
      cubit.setThemeColor(DesignColorRole.primary, '#C09060');
      cubit.toggleVisible('home_bundles');

      expect(await cubit.saveTemplate('ترتيبي'), isTrue);
      expect(repository.templateSaveCalls, 1);
      expect(cubit.state.templates.first.name, 'ترتيبي');
      expect(
        cubit.state.templates.first.updatedAt,
        DateTime(2026, 11, 4, 9),
      );

      // المحفوظ في القاعدة هو ما على الشاشة، لا نسخة مُبسّطة منه.
      final stored = repository.templateFiles[cubit.state.templates.first.id]!;
      expect(stored.theme.colors[DesignColorRole.primary], '#C09060');
      expect(
        stored.rootOf(AppPage.home)?.toMap(),
        cubit.state.document!.rootOf(AppPage.home)?.toMap(),
      );

      cubit.applyBuiltInTemplate(TemplateRegistry.quickOrder);
      expect(cubit.state.document!.sectionsOf(AppPage.home).first.id,
          'home_search');

      await cubit.applySavedTemplate(cubit.state.templates.first.id);
      expect(cubit.state.document!.theme.colors[DesignColorRole.primary],
          '#C09060');
      // رجوع إلى عمل الموظف بحذافيره: ترتيبه وإخفاؤه، لا ترتيب القالب المضمّن.
      expect(cubit.state.document!.sectionsOf(AppPage.home).first.id,
          'home_header');
      expect(
        DesignTree.find(
          cubit.state.document!.rootOf(AppPage.home)!,
          'home_bundles',
        )!.isVisible,
        isFalse,
      );
      // التطبيق لا ينشر: القالب رجوع إلى عمل الموظف، لا قرار نشر.
      expect(repository.publishCalls, 0);
    });

    test('حفظ مرفوض يبقي اللوحة كما كانت ويقول سببًا', () async {
      await open();
      repository.failSave = true;

      expect(await cubit.saveTemplate('لا يصل'), isFalse);
      expect(cubit.state.templates, isEmpty);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('صفحة القاعدة تُعرض، والحذف يزيلها من اللوحة', () async {
      await open();
      repository.templates = <DesignTemplate>[
        DesignTemplate(
          id: 't1',
          name: 'قالب من القاعدة',
          schemaVersion: 2,
          updatedAt: DateTime(2026, 11, 4, 8),
        ),
      ];

      await cubit.refreshTemplates();
      expect(cubit.state.templates.map((t) => t.id), <String>['t1']);

      await cubit.deleteTemplate('t1');
      expect(cubit.state.templates, isEmpty);
      expect(repository.templateDeleteCalls, 1);
    });

    test('قالب مفقود أو قراءة فاشلة: رسالة ولا مستند نصف مبني', () async {
      await open();
      final before = cubit.state.document;

      await cubit.applySavedTemplate('gone');
      expect(cubit.state.document, same(before));
      expect(cubit.state.errorMessage, isNotNull);

      repository.failTemplates = true;
      await cubit.refreshTemplates();
      expect(cubit.state.errorMessage, isNotNull);

      await cubit.applySavedTemplate('gone');
      expect(cubit.state.document, same(before));
    });

    test('محرّر بلا مستند لا يُطبق عليه قالب', () async {
      await open(failLoad: true);
      expect(cubit.state.document, isNull);

      cubit.applyBuiltInTemplate(TemplateRegistry.modernCafe);
      expect(cubit.state.document, isNull);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.canUndo, isFalse);

      expect(await cubit.saveTemplate('اسم'), isFalse);
    });
  });
}
