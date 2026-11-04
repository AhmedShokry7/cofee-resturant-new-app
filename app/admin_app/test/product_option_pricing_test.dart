import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_footer.dart';
import 'package:admin_app/features/option_groups/data/repositories/product_option_assembler.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/features/option_groups/domain/repositories/product_option_repository.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_cubit.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_state.dart';
import 'package:admin_app/features/option_groups/presentation/manager/product_option_draft.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_dialog.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';

/// صفوف الجسور نفسها التي يقرأها المستودع، مكتوبةً يدًا.
Map<String, dynamic> _groupRow(
  String id,
  String name, {
  String appliesTo = 'products',
  bool isActive = true,
}) => {
  'id': id,
  'code': id,
  'name_ar': name,
  'name_en': name,
  'applies_to': appliesTo,
  'selection_type': 'single',
  'is_active': isActive,
  'sort_order': 0,
};

Map<String, dynamic> _valueRow(
  String id,
  String groupId,
  String name,
  num delta, {
  bool isActive = true,
}) => {
  'id': id,
  'group_id': groupId,
  'code': id,
  'name_ar': name,
  'name_en': name,
  'price_delta': delta,
  'is_active': isActive,
  'sort_order': 0,
};

/// يجيب كما تجيب القاعدة: الكتابات تُبدّل الصفوف، والقراءة تُحلّ بها دالةُ 224
/// وتجاوزاتِ 229 — فالشاشة تعرض جوابها لا طلبها.
class _FakeProductOptions implements ProductOptionRepository {
  _FakeProductOptions(
    this._groups,
    this._values, {
    required List<String> attached,
    Map<String, double> pricing = const <String, double>{},
  }) : _attached = attached.toList(),
       _pricing = Map<String, double>.from(pricing);

  final List<Map<String, dynamic>> _groups;
  final List<Map<String, dynamic>> _values;
  final List<String> _attached;
  final Map<String, double> _pricing;

  final List<(String, String, double?)> prices = [];
  final List<(String, String, bool)> bindings = [];

  /// كتابة مقبولة لا تغيّر الجواب: كما ترفض السياسة ربطًا أو تتركه خارج
  /// `effective_product_option_groups`.
  bool refusesWrite = false;

  @override
  Future<List<AdminProductOptionGroup>> loadForProduct(String productId) =>
      Future.value(
        assembleProductOptionGroups(
          groups: _groups,
          values: _values,
          effective: [
            for (final id in _attached) {'group_id': id, 'is_required': false},
          ],
          pricing: [
            for (final entry in _pricing.entries)
              {'value_id': entry.key, 'price_delta': entry.value},
          ],
        ),
      );

  @override
  Future<void> setValuePrice(
    String productId,
    String valueId,
    double? delta,
  ) async {
    prices.add((productId, valueId, delta));
    if (refusesWrite) return;
    if (delta == null) {
      _pricing.remove(valueId);
      return;
    }
    _pricing[valueId] = delta;
  }

  @override
  Future<void> setGroupAttached(
    String productId,
    String groupId,
    bool attached,
  ) async {
    bindings.add((productId, groupId, attached));
    if (refusesWrite) return;
    if (attached) {
      if (!_attached.contains(groupId)) _attached.add(groupId);
      return;
    }
    _attached.remove(groupId);
  }
}

const AdminProduct _latte = AdminProduct(
  id: 'p1',
  nameAr: 'لاتيه',
  nameEn: 'Latte',
  sku: 'SKU-1',
  slug: 'latte',
  basePrice: 10,
);

_FakeProductOptions _repository({
  List<String> attached = const <String>['g1'],
  Map<String, double> pricing = const <String, double>{},
}) {
  return _FakeProductOptions(
    [
      _groupRow('g1', 'Size'),
      _groupRow('g2', 'Extras', appliesTo: 'all'),
      _groupRow('g9', 'Halted', isActive: false),
    ],
    [
      _valueRow('v1', 'g1', 'Small', 0),
      _valueRow('v2', 'g1', 'Large', 3),
      _valueRow('v3', 'g2', 'Milk', 2),
      _valueRow('v9', 'g1', 'Halted', 8, isActive: false),
    ],
    attached: attached,
    pricing: pricing,
  );
}

void _useLargeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AdminProductOptionCubit> _pumpDialog(
  WidgetTester tester,
  ProductOptionRepository repository,
) async {
  _useLargeScreen(tester);
  late final AdminProductOptionCubit cubit;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<AdminProductOptionCubit>(
          create: (_) =>
              cubit = AdminProductOptionCubit(repository: repository)
                ..load(productId: 'p1', basePrice: 10),
          child: const ProductOptionsDialog(product: _latte),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

double _finalPrice(WidgetTester tester, String valueId) => tester
    .widget<AdminMoneyText>(
      find.byKey(ValueKey('product-option-final-$valueId')),
    )
    .value;

String _fieldText(WidgetTester tester, String valueId) => tester
    .widget<TextFormField>(
      find.byKey(ValueKey('product-option-price-$valueId')),
    )
    .controller!
    .text;

AdminProductOptionValue _valueOf(AdminProductOptionState state, String id) {
  for (final group in state.groups) {
    for (final value in group.values) {
      if (value.id == id) return value;
    }
  }
  throw StateError('$id missing');
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('what the database resolved', () {
    test('the per-product override wins over the group delta', () {
      final groups = assembleProductOptionGroups(
        groups: [_groupRow('g1', 'Size')],
        values: [_valueRow('v2', 'g1', 'Large', 3)],
        effective: [
          {'group_id': 'g1', 'is_required': true},
        ],
        pricing: [
          {'value_id': 'v2', 'price_delta': 5},
        ],
      );

      final value = groups.single.values.single;
      expect(groups.single.isAttached, isTrue);
      expect(groups.single.isRequired, isTrue);
      expect(value.groupDelta, 3);
      expect(value.overrideDelta, 5);
      // `catalog.option_value_delta` ترجّع التجاوز، وهو ما يدفعه العميل.
      expect(value.effectiveDelta, 5);
      expect(value.hasOwnPrice, isTrue);
    });

    test('halted groups and halted values are not offered', () {
      final groups = assembleProductOptionGroups(
        groups: [
          _groupRow('g1', 'Size'),
          _groupRow('g9', 'Halted', isActive: false),
        ],
        values: [
          _valueRow('v1', 'g1', 'Small', 0),
          _valueRow('v9', 'g1', 'Halted', 8, isActive: false),
        ],
        effective: const <Map<String, dynamic>>[],
        pricing: const <Map<String, dynamic>>[],
      );

      expect(groups, hasLength(1), reason: 'المجموعة الموقوفة لا تُعرض');
      expect(groups.single.isAttached, isFalse);
      expect(
        groups.single.values,
        hasLength(1),
        reason: 'والقيمة الموقوفة كذلك',
      );
    });
  });

  group('the draft writes only what changed', () {
    test('untouched fields write nothing', () async {
      final state = await _repository().loadForProduct('p1');
      final draft = ProductOptionDraft()..ensure(state);
      expect(draft.changes(state), isEmpty);
      draft.dispose();
    });

    test('a typed number becomes an override', () async {
      final state = await _repository().loadForProduct('p1');
      final draft = ProductOptionDraft()..ensure(state);
      draft.controllers['v2']!.text = '6.5';
      expect(draft.changes(state), {'v2': 6.5});
      draft.dispose();
    });

    test('an empty field means no override, never zero', () async {
      final state = await _repository(pricing: const <String, double>{'v2': 5})
          .loadForProduct('p1');
      final draft = ProductOptionDraft()..ensure(state);

      // الحقل ممتلئ بما عنده من تجاوز، فبلا كتابة لا يُرسل شيء.
      expect(draft.controllers['v2']!.text, '5.00');
      expect(draft.changes(state), isEmpty);

      draft.controllers['v2']!.text = '';
      expect(draft.changes(state), {'v2': null}, reason: 'امحُ لا اكتب صفرًا');
      draft.dispose();
    });

    test('a group the product does not see is never written', () async {
      final state = await _repository(attached: const <String>[])
          .loadForProduct('p1');
      final draft = ProductOptionDraft()..ensure(state);
      draft.controllers['v2']!.text = '9';
      expect(
        draft.changes(state),
        isEmpty,
        reason: 'الحقل معروض للربط لا للتسعير',
      );
      draft.dispose();
    });
  });

  group('the cubit answers with the database', () {
    test('saving writes the change and re-reads the answer', () async {
      final repository = _repository();
      final cubit = AdminProductOptionCubit(repository: repository)
        ..load(productId: 'p1', basePrice: 10);
      await cubit.stream.first;

      final done = await cubit.savePrices({'v2': 5});

      expect(done, isTrue);
      expect(repository.prices, [('p1', 'v2', 5.0)]);
      expect(_valueOf(cubit.state, 'v2').overrideDelta, 5);
      expect(_valueOf(cubit.state, 'v2').effectiveDelta, 5);
      await cubit.close();
    });

    test(
      'a write the answer ignores leaves the screen as the answer says',
      () async {
        final repository = _repository()..refusesWrite = true;
        final cubit = AdminProductOptionCubit(repository: repository)
          ..load(productId: 'p1', basePrice: 10);
        await cubit.stream.first;

        await cubit.toggleAttached('g2', true);

        expect(repository.bindings, [('p1', 'g2', true)]);
        expect(
          cubit.state.groups.firstWhere((g) => g.id == 'g2').isAttached,
          isFalse,
          reason: 'المفتاح حيث وضعته القاعدة، لا حيث طلبته اللوحة',
        );
        await cubit.close();
      },
    );

    test('a failed read reports instead of going blank', () async {
      final cubit = AdminProductOptionCubit(repository: _BrokenOptions());
      // القراءة تُغلق داخل `load` نفسها، فالانتظار على `stream` لا يردّ شيء.
      await cubit.load(productId: 'p1', basePrice: 10);

      expect(cubit.state.status, AdminProductOptionStatus.failure);
      expect(cubit.state.errorMessage, isNotNull);
      await cubit.close();
    });
  });

  group('the dialog', () {
    testWidgets('prices each size of an attached group', (tester) async {
      await _pumpDialog(tester, _repository());

      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      // الأساس ١٠: الصغير بلا زيادة والكبير +٣.
      expect(_finalPrice(tester, 'v1'), 10);
      expect(_finalPrice(tester, 'v2'), 13);

      // المجموعة غير المطبَّقة تُعرض للربط لا للتسعير.
      expect(find.text('Extras'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
      // والقيمة الموقوفة لا سطر لها.
      expect(find.text('Halted'), findsNothing);
    });

    testWidgets('typing moves the preview live', (tester) async {
      await _pumpDialog(tester, _repository());

      await tester.enterText(
        find.byKey(ValueKey('product-option-price-v2')),
        '7',
      );
      await tester.pumpAndSettle();

      expect(_finalPrice(tester, 'v2'), 17);
    });

    testWidgets('the override is shown in the field with no reset for others', (
      tester,
    ) async {
      await _pumpDialog(
        tester,
        _repository(pricing: const <String, double>{'v2': 5}),
      );

      expect(_fieldText(tester, 'v2'), '5.00');
      // +٥ على الأساس، لا +٣ زيادة المجموعة.
      expect(_finalPrice(tester, 'v2'), 15);
      expect(find.byKey(ValueKey('product-option-reset-v2')), findsOneWidget);
      expect(
        find.byKey(ValueKey('product-option-reset-v1')),
        findsNothing,
        reason: 'لا تجاوز ولا كتابة، فلا شيء يُمحى',
      );
    });

    testWidgets('reset deletes the override at once', (tester) async {
      final repository = _repository(pricing: const <String, double>{'v2': 5});
      await _pumpDialog(tester, repository);

      await tester.tap(find.byKey(ValueKey('product-option-reset-v2')));
      await tester.pumpAndSettle();

      expect(repository.prices, [('p1', 'v2', null)]);
      expect(
        _fieldText(tester, 'v2'),
        isEmpty,
        reason: 'يُملى من جواب القاعدة',
      );
      expect(_finalPrice(tester, 'v2'), 13);
      expect(find.byKey(ValueKey('product-option-reset-v2')), findsNothing);
    });

    testWidgets('save writes only what changed', (tester) async {
      final repository = _repository();
      await _pumpDialog(tester, repository);

      await tester.enterText(
        find.byKey(ValueKey('product-option-price-v2')),
        '4',
      );
      await tester.tap(find.byKey(const Key('product-options-save')));
      await tester.pumpAndSettle();

      expect(repository.prices, [('p1', 'v2', 4.0)]);
      expect(_finalPrice(tester, 'v2'), 14);
    });

    testWidgets('a refused save keeps the text and says why', (tester) async {
      await _pumpDialog(tester, _FailingOptions(inner: _repository()));

      await tester.enterText(
        find.byKey(ValueKey('product-option-price-v2')),
        '4',
      );
      await tester.tap(find.byKey(const Key('product-options-save')));
      await tester.pumpAndSettle();

      expect(
        _fieldText(tester, 'v2'),
        '4',
        reason: 'لم تُكتب، فلا تُمحى من الحقل',
      );
      expect(find.byType(AdminErrorBanner), findsWidgets);
    });

    testWidgets('the attach switch asks the repository', (tester) async {
      final repository = _repository();
      await _pumpDialog(tester, repository);

      await tester.tap(find.byKey(ValueKey('product-option-attach-g2')));
      await tester.pumpAndSettle();

      expect(repository.bindings, [('p1', 'g2', true)]);
      // بعد الجواب الجديد تظهر قيم المجموعة التي طُبِّقت.
      expect(find.text('Milk'), findsOneWidget);
    });
  });

  group('the product card menu', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required VoidCallback? onOpenOptions,
      String productId = 'p1',
    }) async {
      _useLargeScreen(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                child: ProductCard(
                  product: AdminProduct(
                    id: productId,
                    nameAr: 'لاتيه',
                    nameEn: 'Latte',
                    sku: 'SKU-1',
                    slug: 'latte',
                    basePrice: 10,
                  ),
                  categories: const <AdminCategory>[],
                  // التذييل — ومنه قائمة «المزيد» — الكتابةُ وحدها تُظهره.
                  onSave: (_) {},
                  onOpenOptions: onOpenOptions,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // زرّ «المزيد» في تذييل البطاقة InkWell لا IconButton، وعنوانه وحده
      // يفرّقه من زرّ «بيانات المنتج» المجاور.
      await tester.tap(
        find.descendant(
          of: find.byType(ProductCardFooter),
          matching: find.widgetWithText(InkWell, S.more),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the entry when the page handed the callback', (
      tester,
    ) async {
      await pumpCard(tester, onOpenOptions: () {});
      expect(find.text(S.optionGroups), findsOneWidget);
    });

    testWidgets('hides it without the hand of the shell', (tester) async {
      await pumpCard(tester, onOpenOptions: null);
      expect(find.text(S.optionGroups), findsNothing);
    });

    testWidgets('hides it for a product that has no row yet', (tester) async {
      await pumpCard(tester, onOpenOptions: () {}, productId: '');
      expect(find.text(S.optionGroups), findsNothing);
    });
  });
}

/// قراءة ترفضها السياسة، كما يرفض `catalog.product.write` كاتبًا لا يملكها.
class _BrokenOptions implements ProductOptionRepository {
  @override
  Future<List<AdminProductOptionGroup>> loadForProduct(String productId) =>
      throw StateError('policy refuses the read');

  @override
  Future<void> setGroupAttached(
    String productId,
    String groupId,
    bool attached,
  ) async {}

  @override
  Future<void> setValuePrice(
    String productId,
    String valueId,
    double? delta,
  ) async {}
}

/// كتابة تنجح في الجسر وتجيب القراءةُ بعدها بالجواب القديم: الصفّ رُفض، فلا
/// تتظاهر اللوحة أنها حفظت.
class _FailingOptions implements ProductOptionRepository {
  _FailingOptions({required this.inner});

  final _FakeProductOptions inner;

  @override
  Future<List<AdminProductOptionGroup>> loadForProduct(String productId) =>
      inner.loadForProduct(productId);

  @override
  Future<void> setGroupAttached(
    String productId,
    String groupId,
    bool attached,
  ) => throw StateError('policy refuses the write');

  @override
  Future<void> setValuePrice(String productId, String valueId, double? delta) =>
      throw StateError('policy refuses the write');
}
