import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/catalog/admin_catalog_snapshot.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/option_groups/data/repositories/admin_option_group_repository.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_option_group_cubit.dart';
import 'package:admin_app/features/option_groups/presentation/pages/option_group_page.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_data_dialog.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_records.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

/// قراءات القاعدة فقط: 020 و225 تسمح لكل موظف بقراءة المجموعات وقيمها
/// المعطَّلة، وتمنع الكتابة بلا `catalog.product.write`، فاللوحة تُظهر أدوات
/// الكتابة لمن يُقبل حفظه وحده.
class _FakeOptionGroupRepository extends AdminOptionGroupRepository {
  _FakeOptionGroupRepository([this.groups = const <AdminOptionGroup>[]]);

  final List<AdminOptionGroup> groups;
  AdminOptionGroup? lastSaved;
  String? lastDeletedId;
  (String, bool)? lastActive;

  @override
  Future<List<AdminOptionGroup>> loadGroups() async => groups;

  @override
  Future<AdminOptionGroup> createGroup(AdminOptionGroup group) async {
    lastSaved = group;
    return group.copyWith(id: 'g-new');
  }

  @override
  Future<AdminOptionGroup> updateGroup(AdminOptionGroup group) async {
    lastSaved = group;
    return group;
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    lastDeletedId = groupId;
  }

  @override
  Future<void> setGroupActive(String groupId, bool isActive) async {
    lastActive = (groupId, isActive);
  }
}

class _FakeCatalogRepository extends AdminProductRepository {
  @override
  Future<AdminCatalogSnapshot> loadCatalog({
    String? branchId,
    int? limit,
    int offset = 0,
    String? search,
  }) async {
    return const AdminCatalogSnapshot(
      products: <AdminProduct>[
        AdminProduct(
          id: 'p1',
          nameAr: 'لاتيه',
          nameEn: 'Latte',
          sku: 'SKU-1',
          slug: 'latte',
          basePrice: 10,
        ),
        AdminProduct(
          id: 'p2',
          nameAr: 'موهو',
          nameEn: 'Mocha',
          sku: 'SKU-2',
          slug: 'mocha',
          basePrice: 12,
        ),
      ],
      categories: <AdminCategory>[
        AdminCategory(id: 'c1', nameAr: 'قهوة', nameEn: 'Coffee'),
      ],
      total: 2,
    );
  }
}

const AdminOptionGroup _sizes = AdminOptionGroup(
  id: 'g1',
  code: 'size',
  nameAr: 'الحجم',
  nameEn: 'Size',
  scope: AdminOptionGroupScope.all,
  values: <AdminOptionValue>[
    AdminOptionValue(code: 's', nameAr: 'صغير', nameEn: 'Small'),
    AdminOptionValue(code: 'l', nameAr: 'كبير', nameEn: 'Large', priceDelta: 3),
  ],
);

const AdminOptionGroup _addOns = AdminOptionGroup(
  id: 'g-addons',
  code: 'toppings',
  nameAr: 'إضافات',
  nameEn: 'Add-ons',
  scope: AdminOptionGroupScope.products,
  selectionType: AdminOptionSelectionType.multiple,
  values: <AdminOptionValue>[
    AdminOptionValue(
      code: 'cheese',
      nameAr: 'جبنة',
      nameEn: 'Cheese',
      priceDelta: 3,
    ),
  ],
);

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AdminOptionGroupCubit> _pumpPage(
  WidgetTester tester, {
  required bool canManage,
  List<AdminOptionGroup> groups = const <AdminOptionGroup>[_addOns],
}) async {
  final cubit = AdminOptionGroupCubit(
    repository: _FakeOptionGroupRepository(groups),
    catalog: _FakeCatalogRepository(),
  );
  final search = AdminSearchController();
  addTearDown(cubit.close);
  addTearDown(search.dispose);
  await cubit.load();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OptionGroupPage(
          searchController: search,
          cubit: cubit,
          canManage: canManage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

/// يفتح الحوار مباشرة: ما يُشتقّ عند الحفظ قرارٌ في واجهة الكتابة لا في
/// القاعدة، فيُقاس هنا بلا شبكة.
Future<(List<AdminOptionGroup>, WidgetTester)> _pumpDialog(
  WidgetTester tester, {
  AdminOptionGroup? initialGroup,
  List<AdminProduct> products = const <AdminProduct>[
    AdminProduct(
      id: 'p1',
      nameAr: 'لاتيه',
      nameEn: 'Latte',
      sku: 'SKU-1',
      slug: 'latte',
      basePrice: 10,
    ),
  ],
}) async {
  _setViewport(tester);
  final saved = <AdminOptionGroup>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OptionGroupDataDialog(
          initialGroup: initialGroup,
          products: products,
          categories: const <AdminCategory>[
            AdminCategory(id: 'c1', nameAr: 'قهوة', nameEn: 'Coffee'),
          ],
          onSave: (group) async => saved.add(group),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (saved, tester);
}

/// الحوار أطول من الشاشة على قياس الاختبار، فالتمرير داخله حقيقي: لا يُلمَس
/// زرّ ولا حقل قبل أن يُبهَر في المدى المرئي.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) =>
    _tapFinder(tester, find.byKey(key));

Future<void> _tapFinder(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Key key, String text) async {
  final target = find.byKey(key);
  await _reveal(tester, target);
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

Future<void> _fillValue(
  WidgetTester tester,
  int index, {
  required String name,
  String? price,
}) async {
  await _type(tester, Key('option-value-name-ar-$index'), name);
  if (price != null) {
    await _type(tester, Key('option-value-price-$index'), price);
  }
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('search', () {
    test('search finds add-on values while keeping sizes off this page', () {
      final found = filterOptionGroups(const <AdminOptionGroup>[
        _sizes,
        _addOns,
      ], 'cheese');
      expect(found, hasLength(1));
      expect(found.single.id, 'g-addons');
    });

    test('the fixed size group is not shown on the add-ons page', () {
      expect(
        filterOptionGroups(const <AdminOptionGroup>[_sizes], 'large'),
        isEmpty,
      );
    });
  });

  group('entity rows', () {
    test('the row carries the scope the database resolves', () {
      final row = _sizes
          .copyWith(
            scope: AdminOptionGroupScope.category,
            selectionType: AdminOptionSelectionType.multiple,
            maxSelect: 2,
          )
          .toRow();
      expect(row['applies_to'], 'category');
      expect(row['selection_type'], 'multiple');
      expect(row['max_select'], 2);
    });

    test('a single group writes no ceiling above one', () {
      // ck_option_groups_single في 008 يقبل واحدًا أو null فقط.
      final row = _sizes.copyWith(maxSelect: null).toRow();
      expect(row['max_select'], isNull);
      expect(row['applies_to'], 'all');
    });

    test('a database row reads back its scope and values', () {
      final group = AdminOptionGroup.fromJson(<String, dynamic>{
        'id': 'g9',
        'code': 'sugar',
        'name_ar': 'السكر',
        'name_en': 'Sugar',
        'applies_to': 'products',
        'selection_type': 'multiple',
        'min_select': 0,
        'max_select': 3,
        'is_required': false,
        'is_active': false,
      });
      expect(group.scope, AdminOptionGroupScope.products);
      expect(group.selectionType, AdminOptionSelectionType.multiple);
      expect(group.maxSelect, 3);
      expect(group.isActive, isFalse);
    });
  });

  group('page gating', () {
    testWidgets('the writer keeps every group control', (tester) async {
      _setViewport(tester);
      await _pumpPage(tester, canManage: true);

      expect(find.text(S.addAddonGroup), findsOneWidget);
      expect(find.text('Add-ons'), findsNWidgets(2));
      expect(find.text(S.delete), findsOneWidget);
      expect(find.text(S.edit), findsOneWidget);
    });

    testWidgets('a reader keeps the groups and loses the writes', (
      tester,
    ) async {
      _setViewport(tester);
      await _pumpPage(tester, canManage: false);

      expect(find.text('Add-ons'), findsNWidgets(2));
      expect(find.text(S.addAddonGroup), findsNothing);
      expect(find.text(S.delete), findsNothing);
      expect(find.text(S.edit), findsNothing);
      expect(find.byType(AdminSelectionCheckBox), findsNothing);
    });

    testWidgets('the card shows each value with what it adds to the price', (
      tester,
    ) async {
      _setViewport(tester);
      await _pumpPage(tester, canManage: false);

      expect(find.text('Cheese'), findsOneWidget);
      // +3: الفارق فوق السعر الأساسي، لا سعر مطلق.
      expect(find.textContaining('3', findRichText: true), findsWidgets);
    });
  });

  group('dialog saves', () {
    testWidgets('a required single group derives one minimum and one ceiling', (
      tester,
    ) async {
      final (saved, _) = await _pumpDialog(tester);

      await _type(tester, Key('option-group-name-ar'), 'Size');
      await _tap(tester, Key('option-group-required'));

      await _tap(tester, Key('option-group-add-value'));
      await _fillValue(tester, 0, name: 'Small');
      await _fillValue(tester, 1, name: 'Large', price: '3');

      await _tap(tester, Key('option-group-save'));

      expect(saved, hasLength(1));
      final group = saved.single;
      expect(group.selectionType, AdminOptionSelectionType.single);
      expect(group.minSelect, 1);
      expect(group.maxSelect, 1);
      expect(group.productIds, isEmpty);
      expect(group.values[1].priceDelta, 3);
    });

    testWidgets('a product option template can be saved before assignment', (
      tester,
    ) async {
      final (saved, _) = await _pumpDialog(tester);

      await _type(tester, Key('option-group-name-ar'), 'Size');
      await _tap(tester, Key('option-group-add-value'));
      await _fillValue(tester, 0, name: 'Small');
      await _fillValue(tester, 1, name: 'Large');

      expect(find.text(S.optionGroupProductAssignmentHelper), findsOneWidget);
      await _tap(tester, Key('option-group-save'));

      expect(saved, hasLength(1));
      expect(saved.single.scope, AdminOptionGroupScope.products);
      expect(saved.single.productIds, isEmpty);
    });

    testWidgets('codes are generated from names automatically', (tester) async {
      final (saved, _) = await _pumpDialog(tester);

      await _type(tester, Key('option-group-name-ar'), 'إضافة جديدة');
      await _fillValue(tester, 0, name: 'شوت إسبريسو');

      await _tap(tester, Key('option-group-save'));

      expect(saved, hasLength(1));
      expect(saved.single.code, matches(RegExp(r'^[a-z_]+$')));
      expect(saved.single.values.single.code, 'option_1');
    });

    testWidgets('one value is enough for a simple add-on', (tester) async {
      final (saved, _) = await _pumpDialog(tester);

      await _type(tester, Key('option-group-name-ar'), 'إضافة كريمة');
      await _fillValue(tester, 0, name: 'كريمة', price: '2');

      await _tap(tester, Key('option-group-save'));

      expect(saved, hasLength(1));
      expect(saved.single.values.single.nameAr, 'كريمة');
      expect(saved.single.values.single.priceDelta, 2);
    });

    testWidgets('switching the scope keeps only the list that scope uses', (
      tester,
    ) async {
      final (saved, _) = await _pumpDialog(
        tester,
        initialGroup: _sizes.copyWith(
          scope: AdminOptionGroupScope.products,
          productIds: const <String>['p1'],
          excludedProductIds: const <String>['p2'],
        ),
        products: const <AdminProduct>[
          AdminProduct(
            id: 'p1',
            nameAr: 'لاتيه',
            nameEn: 'Latte',
            sku: 'SKU-1',
            slug: 'latte',
            basePrice: 10,
          ),
          AdminProduct(
            id: 'p2',
            nameAr: 'موهو',
            nameEn: 'Mocha',
            sku: 'SKU-2',
            slug: 'mocha',
            basePrice: 12,
          ),
        ],
      );

      // من منتجات محددة إلى فئة: قائمة المنتقى تُمسح، فما يُبقيهِ النطاق
      // الجديد ظاهرٌ في أداته لا في ذاكرته وحدَها.
      await _tapFinder(tester, find.text(S.scopeCategories));
      await _tap(tester, Key('admin-pickable-c1'));

      await _tap(tester, Key('option-group-save'));

      expect(saved, hasLength(1));
      expect(saved.single.scope, AdminOptionGroupScope.category);
      expect(saved.single.categoryIds, <String>['c1']);
      expect(saved.single.productIds, isEmpty);
      // الاستثناءات تُعرض لكل نطاق ما عدا «منتجات محددة»، فتحفظها كما تراها.
      expect(saved.single.excludedProductIds, <String>['p2']);
    });

    testWidgets('a blank choice row says which row it is', (tester) async {
      final (saved, _) = await _pumpDialog(tester);

      await _type(tester, Key('option-group-name-ar'), 'Size');
      await _tap(tester, Key('option-group-add-value'));
      await _tap(tester, Key('option-group-add-value'));
      await _fillValue(tester, 0, name: 'Small');
      await _fillValue(tester, 1, name: 'Large');

      await _tap(tester, Key('option-group-save'));

      // السطر الثالث فارغ: الجملة تحمل رقمه، فـ «الاسم مطلوب» وحدها تتيه
      // بين ثلاثة أسطر في حوار واحد.
      expect(saved, isEmpty);
      expect(find.text(S.optionValueNeedsName(3)), findsOneWidget);
    });
  });

  group('cubit', () {
    test('the saved group keeps the id the database gave it', () async {
      final cubit = AdminOptionGroupCubit(
        repository: _FakeOptionGroupRepository(),
        catalog: _FakeCatalogRepository(),
      );
      addTearDown(cubit.close);

      await cubit.createGroup(_sizes.copyWith(id: ''));

      expect(cubit.state.groups, hasLength(1));
      expect(cubit.state.groups.single.id, 'g-new');
    });

    test('a failure keeps the message the screen shows', () async {
      final cubit = AdminOptionGroupCubit(
        repository: _ThrowingOptionGroupRepository(),
        catalog: _FakeCatalogRepository(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
    });
  });
}

class _ThrowingOptionGroupRepository extends AdminOptionGroupRepository {
  @override
  Future<List<AdminOptionGroup>> loadGroups() async {
    throw Exception('load failed');
  }
}
