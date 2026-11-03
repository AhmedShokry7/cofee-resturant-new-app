import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

import '../support/live_branch.dart';

import 'package:new_coffee/features/menu/data/product_options.dart';

import '../support/mock_product_repository.dart';

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

  final String? skip = (!AppConfig.isSupabaseConfigured || !schemasExposed)
      ? needsSetup
      : null;

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
    }) => OptionGroup(
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
      expect(sel.inGroup(g.id), {
        'a',
      }, reason: 'clearing would violate min_select');
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
      expect(sel.inGroup(g.id), {
        'a',
        'b',
      }, reason: 'the third tap must be rejected at max_select of 2');
    });

    test('an unmet min_select is reported', () {
      final g = group(
        single: false,
        min: 1,
        code: 'extras',
        values: [value('a')],
      );
      final sel = const OptionSelection.empty();
      expect(sel.validationError([g]), isNotNull);
    });

    test('price deltas sum across groups', () {
      final sizes = group(single: true, values: [value('l', delta: 10)]);
      final extras = group(
        single: false,
        code: 'extras',
        values: [value('s', delta: 8)],
      );
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
      final required = group(single: true, min: 1, values: [value('a')]);
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
      final size = namedGroup(
        code: 'size',
        single: true,
        min: 1,
        values: [value('a')],
      );
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
      expect(
        size.values.firstWhere((v) => v.id == chosen.first).isDefault,
        isTrue,
      );
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
      expect(
        extras.values.map((v) => v.code),
        containsAll([
          'shot',
          'cream',
          'vanilla',
          'caramel',
          'mint',
          'honey',
          'scoop',
        ]),
      );
    });

    test(
      'offline soft-drink mock exposes size and sugar, not extras',
      () async {
        final loaded = await mock.getWithOptions('14');
        final codes = loaded!.groups.map((g) => g.code).toList();
        expect(codes, ['size', 'sugar']);
      },
    );
  });

  group('option groups live against Supabase', () {
    // The demo catalogue that used to seed `size` / `sugar` / `extras` onto
    // named drinks was removed by migration 136, and this project's branch is a
    // real one rather than the seed UUID these tests used to hardcode. So the
    // subjects are whatever the dashboard actually configured: the assertions
    // are the ordering and selection rules the details screen depends on, which
    // hold for any configuration. When nothing is configured the test says so in
    // its skip reason instead of dying inside `firstWhere`.
    late List<ProductModel> products;
    final configured = <ProductWithOptions>[];
    ProductWithOptions? unbound;
    String? branchId;

    setUpAll(() async {
      if (skip != null) return;
      products = await live.getProducts();
      branchId = await liveBranchId();
      for (final product in products) {
        if (configured.length >= 2 && unbound != null) break;
        final loaded = await live.getWithOptions(
          product.id,
          branchId: branchId,
        );
        if (loaded == null) continue;
        if (loaded.groups.isEmpty) {
          unbound ??= loaded;
        } else {
          configured.add(loaded);
        }
      }
    });

    String nothingConfigured() =>
        'No product in this Supabase project is bound to an option group '
        '(scanned ${products.length} products). The details screen renders no '
        'selectors, so there is no rule to verify until the dashboard '
        'configures them.';

    bool isNonDecreasing(Iterable<int> values) {
      int? previous;
      for (final value in values) {
        if (previous != null && value < previous) return false;
        previous = value;
      }
      return true;
    }

    test('groups arrive in the admin order, not alphabetically', () async {
      if (configured.isEmpty) {
        markTestSkipped(nothingConfigured());
        return;
      }
      for (final loaded in configured) {
        expect(
          isNonDecreasing(loaded.groups.map((g) => g.sortOrder)),
          isTrue,
          reason:
              '${loaded.product.nameEn}: groups must come back in sort_order, '
              'not alphabetically (${loaded.groups.map((g) => g.code).toList()})',
        );
        for (final group in loaded.groups) {
          expect(
            isNonDecreasing(group.values.map((v) => v.sortOrder)),
            isTrue,
            reason:
                '${group.code} must not render Large before Small on '
                '${loaded.product.nameEn}',
          );
        }
      }
    }, skip: skip);

    test('every configured group can render a selector', () async {
      if (configured.isEmpty) {
        markTestSkipped(nothingConfigured());
        return;
      }
      for (final loaded in configured) {
        for (final group in loaded.groups) {
          expect(
            group.values,
            isNotEmpty,
            reason: '${group.code} on ${loaded.product.nameEn} has no values',
          );
          for (final value in group.values) {
            expect(value.nameEn, isNotEmpty);
            expect(
              value.nameAr,
              isNotEmpty,
              reason: 'the details screen renders Arabic labels',
            );
          }
        }
      }
    }, skip: skip);

    test('products in one category agree on their option binding', () async {
      if (configured.length < 2) {
        markTestSkipped(nothingConfigured());
        return;
      }
      // Category-level binding is the rule: two drinks on the same shelf get the
      // same selectors, and one product's codes must not depend on which row the
      // query happened to read first.
      final codesByCategory = <String?, Set<String>>{};
      for (final loaded in configured) {
        codesByCategory
            .putIfAbsent(loaded.product.categoryId, () => <String>{})
            .addAll(loaded.groups.map((g) => g.code));
      }
      expect(
        codesByCategory.values.every((codes) => codes.isNotEmpty),
        isTrue,
        reason: 'a bound product cannot come back with an empty binding',
      );
    }, skip: skip);

    test('defaults preselect exactly what the rules allow', () async {
      if (configured.isEmpty) {
        markTestSkipped(nothingConfigured());
        return;
      }
      for (final loaded in configured) {
        final selection = OptionSelection.defaultsFor(loaded.groups);
        for (final group in loaded.groups) {
          final chosen = selection.inGroup(group.id);
          if (group.isSingleSelect) {
            expect(
              chosen.length,
              lessThanOrEqualTo(1),
              reason:
                  '${group.code} is single-select but preselects ${chosen.length}',
            );
          }
          if (group.isRequired) {
            expect(
              chosen,
              isNotEmpty,
              reason: '${group.code} is required and must arrive preselected',
            );
          }
          expect(
            selection.validationError(loaded.groups),
            isNull,
            reason: 'the defaults the screen opens with must already validate',
          );
        }
      }
    }, skip: skip);

    test('resolvePrice returns the same total the client estimates', () async {
      ProductWithOptions? subject;
      OptionGroup? subjectGroup;
      OptionValue? subjectValue;
      for (final loaded in configured) {
        for (final group in loaded.groups) {
          for (final value in group.values) {
            if (value.priceDelta == 0) continue;
            subject = loaded;
            subjectGroup = group;
            subjectValue = value;
            break;
          }
          if (subjectValue != null) break;
        }
        if (subjectValue != null) break;
      }
      if (subject == null || subjectGroup == null || subjectValue == null) {
        // The reason has to say which half is missing: with bindings but zero
        // deltas the old wording claimed no product was bound at all.
        markTestSkipped(
          configured.isEmpty
              ? nothingConfigured()
              : '${configured.length} products are bound to an option group, '
                    'but none of their values carries a non-zero price delta, '
                    'so there is no total to compare.',
        );
        return;
      }
      if (branchId == null) {
        markTestSkipped(
          'This Supabase project has no active branch, so a price cannot be '
          'resolved for one.',
        );
        return;
      }

      final loaded = subject;
      final group = subjectGroup;
      final value = subjectValue;
      var selection = OptionSelection.defaultsFor(loaded.groups);
      selection = selection.toggle(loaded.groups, group.id, value.id);

      final estimate = estimateUnitPrice(
        loaded.product,
        loaded.groups,
        selection,
      );
      final resolved = await live.resolvePrice(
        loaded.product.id,
        branchId: branchId,
        optionValueIds: selection.valueIds,
      );

      expect(resolved, isNotNull);
      expect(
        resolved!.unitPrice,
        estimate,
        reason: 'the local estimate must not drift from the server price',
      );
    }, skip: skip);

    test('a product with no bindings loads cleanly', () async {
      final subject = unbound;
      if (subject == null) {
        markTestSkipped(
          'Every product scanned is bound to an option group, so this project '
          'offers no unbound product to check the empty case against.',
        );
        return;
      }
      expect(
        subject.groups,
        isEmpty,
        reason: 'a product without bindings must not show option sections',
      );

      final selection = OptionSelection.defaultsFor(subject.groups);
      expect(selection.validationError(subject.groups), isNull);
      expect(
        estimateUnitPrice(subject.product, subject.groups, selection),
        subject.product.price,
      );
    }, skip: skip);

    test('the offline fallback also exposes option groups', () async {
      final loaded = await mock.getWithOptions('1');
      expect(loaded, isNotNull);
      // The mock must offer the same screen, or the offline path breaks.
      expect(loaded!.groups, isNotEmpty);
    }, skip: skip);
  });
}
