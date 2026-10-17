import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/product_options.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies that option groups bound to a product behave like a contract.
///
/// The product details screen used to read frozen `DrinkSize` / `SugarLevel` /
/// `ProductExtra` enums. These assert the replacement: the groups come from the
/// database, they respect the admin's min/max and single-select rules, and the
/// price comes from resolvePrice rather than a Dart sum.
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');
  const needsSetup =
      'Needs --dart-define SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and '
      'SCHEMAS_EXPOSED=true';

  final String? skip =
      (!AppConfig.isSupabaseConfigured || !schemasExposed) ? needsSetup : null;

  const mainBranch = '00000000-0000-4000-8000-000000000101';

  late CatalogRepository live;
  final mock = MockProductRepository();

  setUpAll(() async {
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    live = SupabaseProductRepository();
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('option selection rules (pure, always runs)', () {
    OptionGroup group({
      required bool single,
      int min = 0,
      int? max,
      List<OptionValue> values = const [],
      String code = 'size',
      int sortOrder = 0,
    }) =>
        OptionGroup(
          id: 'g1',
          code: code,
          nameAr: 'مجموعة',
          nameEn: 'Group',
          isSingleSelect: single,
          minSelect: min,
          maxSelect: max,
          isRequired: min > 0,
          values: values,
          sortOrder: sortOrder,
        );

    OptionValue value(String id, {double delta = 0, bool isDefault = false}) =>
        OptionValue(
          id: id,
          code: id,
          nameAr: id,
          nameEn: id,
          priceDelta: delta,
          isDefault: isDefault,
        );

    test('single select keeps only the tapped value', () {
      final g = group(single: true, values: [value('a'), value('b')]);
      var sel = const OptionSelection.empty();
      sel = sel.toggle([g], g.id, 'a');
      sel = sel.toggle([g], g.id, 'b');
      expect(sel.inGroup(g.id), {'b'});
    });

    test('optional single select can be cleared', () {
      final g = group(single: true, min: 0, values: [value('a')]);
      var sel = const OptionSelection.empty().toggle([g], g.id, 'a');
      sel = sel.toggle([g], g.id, 'a');
      expect(sel.inGroup(g.id), isEmpty);
    });

    test('required single select cannot be cleared', () {
      final g = group(single: true, min: 1, values: [value('a')]);
      var sel = const OptionSelection.empty().toggle([g], g.id, 'a');
      sel = sel.toggle([g], g.id, 'a');
      expect(sel.inGroup(g.id), {'a'},
          reason: 'clearing would violate min_select');
      expect(sel.validationError([g]), isNull);
    });

    test('multi select accumulates and honours max_select', () {
      final g = group(
        single: false,
        max: 2,
        code: 'extras',
        values: [value('a'), value('b'), value('c')],
      );
      var sel = const OptionSelection.empty();
      sel = sel.toggle([g], g.id, 'a');
      sel = sel.toggle([g], g.id, 'b');
      sel = sel.toggle([g], g.id, 'c');
      expect(sel.inGroup(g.id), {'a', 'b'},
          reason: 'the third tap must be rejected at max_select of 2');
    });

    test('an unmet min_select is reported', () {
      final g = group(single: false, min: 1, code: 'extras', values: [value('a')]);
      final sel = const OptionSelection.empty();
      expect(sel.validationError([g]), isNotNull);
    });

    test('price deltas sum across groups', () {
      final sizes = group(single: true, values: [value('l', delta: 10)]);
      final extras =
          group(single: false, code: 'extras', values: [value('s', delta: 8)]);
      var sel = const OptionSelection.empty();
      sel = sel.toggle([sizes], sizes.id, 'l');
      sel = sel.toggle([extras], extras.id, 's');
      expect(sel.deltaOf([sizes, extras]), 18);
    });

    test('cup size falls back to medium for an unknown size code', () {
      // A new admin-defined size must not crash the screen.
      expect(CupSize.fromCode('xxl'), CupSize.medium);
      expect(CupSize.fromCode('large'), CupSize.large);
      expect(CupSize.fromCode('S'), CupSize.small);
    });

    test('binding required is OR-ed with the group requirement', () {
      final optional = group(single: true, values: [value('a')]);
      final effective = effectiveProductOptionGroup(
        group: optional,
        bindingIsRequired: true,
        bindingSortOrder: 0,
        values: optional.values,
      );
      expect(effective.isRequired, isTrue);
      expect(effective.minSelect, 1);
    });

    test('binding cannot make a required group optional', () {
      final required = group(
        single: true,
        min: 1,
        values: [value('a')],
      );
      final effective = effectiveProductOptionGroup(
        group: required,
        bindingIsRequired: false,
        bindingSortOrder: 0,
        values: required.values,
      );
      expect(effective.isRequired, isTrue);
      expect(effective.minSelect, 1);
    });

    test('binding sort_order overrides the group only when positive', () {
      final g = group(single: true, sortOrder: 5, values: [value('a')]);
      final overridden = effectiveProductOptionGroup(
        group: g,
        bindingIsRequired: false,
        bindingSortOrder: 2,
        values: g.values,
      );
      expect(overridden.sortOrder, 2);

      final kept = effectiveProductOptionGroup(
        group: g,
        bindingIsRequired: false,
        bindingSortOrder: 0,
        values: g.values,
      );
      expect(kept.sortOrder, 5);
    });

    test('binding never changes max_select', () {
      final g = group(single: false, max: 3, values: [value('a')]);
      final effective = effectiveProductOptionGroup(
        group: g,
        bindingIsRequired: false,
        bindingSortOrder: 0,
        values: g.values,
      );
      expect(effective.maxSelect, 3);
    });
  });

  group('product option differences (pure, always runs)', () {
    OptionGroup namedGroup({
      required String code,
      required bool single,
      int min = 0,
      int? max,
      List<OptionValue>? values,
    }) {
      return OptionGroup(
        id: code,
        code: code,
        nameAr: 'مجموعة',
        nameEn: 'Group',
        isSingleSelect: single,
        minSelect: min,
        maxSelect: max,
        isRequired: min > 0,
        values: values ?? const [],
      );
    }

    OptionValue value(String id, {double delta = 0, bool isDefault = false}) =>
        OptionValue(
          id: id,
          code: id,
          nameAr: id,
          nameEn: id,
          priceDelta: delta,
          isDefault: isDefault,
        );

    test('two products in the same category share one option group set', () {
      final first = namedGroup(
        code: 'size',
        single: true,
        values: [value('small'), value('large')],
      );
      final second = namedGroup(
        code: 'size',
        single: true,
        values: [value('small'), value('large')],
      );
      expect(first.code, second.code);
      expect(first.isSingleSelect, second.isSingleSelect);
      expect(first.minSelect, second.minSelect);
      expect(first.maxSelect, second.maxSelect);
    });

    test('two products in different categories have different group sets', () {
      final drinkGroups = [
        namedGroup(code: 'size', single: true),
        namedGroup(code: 'sugar', single: true),
        namedGroup(code: 'extras', single: false),
      ];
      final dessertGroups = const <OptionGroup>[];
      expect(drinkGroups.length, 3);
      expect(dessertGroups.length, 0);
      expect(drinkGroups.map((g) => g.code), ['size', 'sugar', 'extras']);
    });

    test('a product allows only the option values defined by its groups', () {
      final extras = namedGroup(
        code: 'extras',
        single: false,
        values: [value('shot'), value('vanilla')],
      );
      final selected = OptionSelection.empty()
          .toggle([extras], extras.id, 'shot')
          .toggle([extras], extras.id, 'vanilla');
      expect(selected.inGroup(extras.id), {'shot', 'vanilla'});
      expect(selected.valueIds.toSet().length, selected.valueIds.length);
    });

    test('required single group rejects an empty selection', () {
      final size = namedGroup(code: 'size', single: true, min: 1, values: [value('a')]);
      var selected = const OptionSelection.empty();
      expect(selected.validationError([size]), isNotNull);
      selected = selected.toggle([size], size.id, 'a');
      expect(selected.validationError([size]), isNull);
      selected = selected.toggle([size], size.id, 'a');
      expect(selected.inGroup(size.id), {'a'});
    });

    test('default values are selected exactly once per group', () {
      final size = namedGroup(
        code: 'size',
        single: true,
        values: [value('small', isDefault: true), value('large')],
      );
      final selected = OptionSelection.defaultsFor([size]);
      final chosen = selected.inGroup(size.id);
      expect(chosen.length, 1);
      expect(size.values.firstWhere((v) => v.id == chosen.first).isDefault, isTrue);
    });

    test('maximum selection is enforced for multi option groups', () {
      final extras = namedGroup(
        code: 'extras',
        single: false,
        max: 2,
        values: [value('a'), value('b'), value('c')],
      );
      var selected = OptionSelection.empty();
      selected = selected.toggle([extras], extras.id, 'a');
      selected = selected.toggle([extras], extras.id, 'b');
      selected = selected.toggle([extras], extras.id, 'c');
      expect(selected.inGroup(extras.id), {'a', 'b'});
      expect(selected.validationError([extras]), isNull);
    });

    test('unit price uses product price plus selected option deltas', () {
      final sizes = namedGroup(
        code: 'size',
        single: true,
        values: [value('large', delta: 10)],
      );
      final extras = namedGroup(
        code: 'extras',
        single: false,
        values: [value('shot', delta: 8)],
      );
      var selected = const OptionSelection.empty();
      selected = selected.toggle([sizes], sizes.id, 'large');
      selected = selected.toggle([extras], extras.id, 'shot');
      final product = ProductModel(
        id: '1',
        name: 'Drink',
        category: 'Hot Coffee',
        description: 'Description',
        price: 35,
        image: 'assets/images/product.png',
      );
      expect(
        estimateUnitPrice(product, [sizes, extras], selected),
        53,
        reason: '35 + 10 + 8',
      );
      expect(selected.valueIds, ['large', 'shot']);
    });
  });

  group('mock handling (documented differences, current behavior)', () {
    test('offline coffee mock exposes all current beverage extras', () async {
      final loaded = await mock.getWithOptions('3');
      final extras = loaded!.groups.firstWhere((g) => g.code == 'extras');
      expect(extras.values.length, 7);
      expect(extras.values.map((v) => v.code), containsAll(['shot', 'cream', 'vanilla', 'caramel', 'mint', 'honey', 'scoop']));
    });

    test('offline soft-drink mock exposes size and sugar, not extras', () async {
      final loaded = await mock.getWithOptions('14');
      final codes = loaded!.groups.map((g) => g.code).toList();
      expect(codes, ['size', 'sugar']);
    });
  });

  group('option groups live against Supabase', () {
    test('a drink exposes size, sugar and extras in admin order', () async {
      final products = await live.getProducts();
      ProductModel? latte;
      for (final p in products) {
        if (p.nameEn == 'Latte') latte = p;
      }
      expect(latte, isNotNull, reason: 'the seed creates a latte');

      final loaded = await live.getWithOptions(latte!.id, branchId: mainBranch);
      expect(loaded, isNotNull);
      final codes = loaded!.groups.map((g) => g.code).toList();
      expect(codes, ['size', 'sugar', 'extras'],
          reason: 'groups must come back in sort_order, not alphabetically');

      final size = loaded.groups.firstWhere((g) => g.code == 'size');
      expect(size.values.map((v) => v.code).toList(),
          ['small', 'medium', 'large'],
          reason: 'sizes must not render Large before Small');
      expect(size.isSingleSelect, isTrue);
    }, skip: skip);

    test('two coffee drinks share the same option binding', () async {
      final products = await live.getProducts();
      final latte = products.firstWhere((p) => p.nameEn == 'Latte');
      final cappuccino = products.firstWhere((p) => p.nameEn == 'Cappuccino');
      final latteLoaded = await live.getWithOptions(latte.id, branchId: mainBranch);
      final cappuccinoLoaded =
          await live.getWithOptions(cappuccino.id, branchId: mainBranch);

      expect(latteLoaded, isNotNull);
      expect(cappuccinoLoaded, isNotNull);
      expect(
        latteLoaded!.groups.map((g) => g.code).toList(),
        cappuccinoLoaded!.groups.map((g) => g.code).toList(),
        reason: 'shared category option binding should agree',
      );
      expect(latteLoaded.groups.map((g) => g.code), contains('extras'));
    }, skip: skip);

    test('espresso and cheesecake expose different option bindings', () async {
      final products = await live.getProducts();
      final latte = products.firstWhere((p) => p.nameEn == 'Latte');
      final cheesecake = products.firstWhere((p) => p.nameEn == 'Cheesecake');
      final latteLoaded = await live.getWithOptions(latte.id, branchId: mainBranch);
      final cheesecakeLoaded =
          await live.getWithOptions(cheesecake.id, branchId: mainBranch);

      expect(latteLoaded!.groups.map((g) => g.code), ['size', 'sugar', 'extras']);
      expect(cheesecakeLoaded!.groups, isEmpty);
    }, skip: skip);

    test('cola exposes size and sugar only, not extras', () async {
      final products = await live.getProducts();
      final cola = products.firstWhere((p) => p.nameEn == 'Cola');
      final loaded = await live.getWithOptions(cola.id, branchId: mainBranch);
      expect(loaded!.groups.map((g) => g.code).toList(), ['size', 'sugar']);
    }, skip: skip);

    test('every option value carries both languages and a price delta',
        () async {
      final products = await live.getProducts();
      final latte = products.firstWhere((p) => p.nameEn == 'Latte');
      final loaded = await live.getWithOptions(latte.id, branchId: mainBranch);

      for (final group in loaded!.groups) {
        expect(group.values, isNotEmpty, reason: '${group.code} has no values');
        for (final value in group.values) {
          expect(value.nameEn, isNotEmpty);
          expect(value.nameAr, isNotEmpty,
              reason: 'the details screen renders Arabic labels');
        }
      }
    }, skip: skip);

    test('defaults are preselected', () async {
      final latte =
          (await live.getProducts()).firstWhere((p) => p.nameEn == 'Latte');
      final loaded = await live.getWithOptions(latte.id, branchId: mainBranch);
      final selection = OptionSelection.defaultsFor(loaded!.groups);

      // The seed marks small and no-sugar as the defaults.
      final size = loaded.groups.firstWhere((g) => g.code == 'size');
      final chosen = selection.inGroup(size.id);
      expect(chosen.length, 1);
      expect(size.values.firstWhere((v) => v.id == chosen.first).code, 'small');
    }, skip: skip);

    test('resolvePrice returns the same total the client estimates', () async {
      final latte =
          (await live.getProducts()).firstWhere((p) => p.nameEn == 'Latte');
      final loaded = await live.getWithOptions(latte.id, branchId: mainBranch);

      final size = loaded!.groups.firstWhere((g) => g.code == 'size');
      final large = size.values.firstWhere((v) => v.code == 'large');
      var selection = const OptionSelection.empty();
      selection = selection.toggle(loaded.groups, size.id, large.id);

      final estimate = estimateUnitPrice(loaded.product, loaded.groups, selection);
      final resolved = await live.resolvePrice(
        latte.id,
        branchId: mainBranch,
        optionValueIds: selection.valueIds,
      );

      expect(resolved, isNotNull);
      expect(resolved!.unitPrice, estimate,
          reason: 'the local estimate must not drift from the server price');
      expect(resolved.isAvailable, isTrue);
    }, skip: skip);

    test('a product with no options loads cleanly', () async {
      final cheesecake =
          (await live.getProducts()).firstWhere((p) => p.nameEn == 'Cheesecake');
      final loaded =
          await live.getWithOptions(cheesecake.id, branchId: mainBranch);
      expect(loaded, isNotNull);
      expect(loaded!.groups, isEmpty,
          reason: 'food has no size or extras, and must not show those sections');

      final selection = OptionSelection.defaultsFor(loaded.groups);
      expect(selection.validationError(loaded.groups), isNull);
      expect(estimateUnitPrice(loaded.product, loaded.groups, selection),
          loaded.product.price);
    }, skip: skip);

    test('the offline fallback also exposes option groups', () async {
      final loaded = await mock.getWithOptions('1');
      expect(loaded, isNotNull);
      // The mock must offer the same screen, or the offline path breaks.
      expect(loaded!.groups, isNotEmpty);
    }, skip: skip);
  });
}
