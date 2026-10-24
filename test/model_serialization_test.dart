import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serialization tests for the bilingual model layer.
///
/// The JSON fixtures below are the exact column names PostgREST returns for
/// `catalog.products` and `catalog.categories`, so a schema drift shows up here
/// rather than as an empty screen at runtime.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  group('ProductModel.fromJson', () {
    // Shape produced by joining catalog.products with catalog.categories.
    const productRow = {
      'id': 'b1f0c111-0000-4000-8000-000000000001',
      'category_id': 'b1f0c111-0000-4000-8000-0000000000c1',
      'sku': 'CF-003',
      'slug': 'latte',
      'name_ar': 'لاتيه',
      'name_en': 'Latte',
      'description_ar': 'إسبريسو مع حليب',
      'description_en': 'Espresso with steamed milk',
      'base_price': '35.00',
      'compare_at_price': null,
      'image_url': 'assets/images/product.png',
      'is_active': true,
      'is_featured': true,
      'prep_minutes': 4,
      'category_name_ar': 'قهوة ساخنة',
      'category_name_en': 'Hot Coffee',
    };

    test('reads the snake_case columns PostgREST returns', () {
      final p = ProductModel.fromJson(productRow);
      expect(p.id, productRow['id']);
      expect(p.sku, 'CF-003');
      expect(p.slug, 'latte');
      expect(p.categoryId, productRow['category_id']);
      expect(p.price, 35.0);
      expect(p.oldPrice, isNull);
      expect(p.isFeatured, isTrue);
      expect(p.prepMinutes, 4);
    });

    test('parses a numeric delivered as a string', () {
      // Postgres numeric often arrives quoted; a naive cast would yield 0.
      expect(Db.asDouble('35.00'), 35.0);
      expect(Db.asDouble(35), 35.0);
      expect(Db.asDouble(null, fallback: -1), -1);
      expect(Db.asDoubleOrNull('19.99'), 19.99);
      expect(Db.asDoubleOrNull(null), isNull);
      expect(Db.asDouble('not-a-number', fallback: 7), 7);
    });

    test('switches language without changing the underlying fields', () {
      final p = ProductModel.fromJson(productRow);
      expect(p.name, 'لاتيه');
      expect(p.category, 'قهوة ساخنة');

      AppLocale.instance.debugSet(AppLanguage.english);
      expect(p.name, 'Latte');
      expect(p.description, 'Espresso with steamed milk');
      expect(p.category, 'Hot Coffee');

      // The stored pair is untouched by the locale.
      expect(p.nameAr, 'لاتيه');
      expect(p.nameEn, 'Latte');
    });

    test('falls back to the other language instead of showing blank', () {
      final partial = ProductModel.fromJson({
        ...productRow,
        'name_ar': null,
        'name_en': 'Iced Latte',
      });
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(
        partial.name,
        'Iced Latte',
        reason: 'missing Arabic must fall back, not render empty',
      );
    });

    test('legacy mock data still resolves its single-language name', () {
      // The shape menu_list.dart still produces.
      const legacy = ProductModel(
        id: '3',
        name: 'Latte',
        category: 'Hot Coffee',
        description: 'Espresso with steamed milk',
        price: 35.0,
        image: 'assets/images/product.png',
      );
      expect(legacy.name, 'Latte');
      expect(legacy.category, 'Hot Coffee');
      expect(legacy.description, 'Espresso with steamed milk');
      expect(legacy.hasDiscount, isFalse);
    });

    test('a compare-at price is a reference price, not a discount', () {
      final withCompareAt = ProductModel.fromJson({
        ...productRow,
        'base_price': '40.00',
        'compare_at_price': '50.00',
      });
      expect(withCompareAt.oldPrice, 50.0);
      // The old price is shown next to the price, but nothing was reduced, so
      // nothing may claim that the product is discounted.
      expect(withCompareAt.hasOldPrice, isTrue);
      expect(withCompareAt.hasDiscount, isFalse);
      expect(withCompareAt.appliedDiscountPercentage, isNull);
    });

    test('an applied discount is reported as one', () {
      final discounted = ProductModel(
        id: 'p1',
        name: 'Latte',
        price: 36,
        oldPrice: 40,
        appliedDiscountPercentage: 10,
        image: 'assets/images/product.png',
      );
      expect(discounted.hasDiscount, isTrue);
      expect(discounted.hasOldPrice, isTrue);
      expect(discounted.appliedDiscountPercentage, 10);
    });

    test('survives a toJson round trip', () {
      final original = ProductModel.fromJson(productRow);
      final restored = ProductModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.nameAr, original.nameAr);
      expect(restored.nameEn, original.nameEn);
      expect(restored.price, original.price);
      expect(restored.categoryId, original.categoryId);
    });
  });

  group('CategoryModel.fromJson', () {
    const categoryRow = {
      'id': 'b1f0c111-0000-4000-8000-0000000000c1',
      'slug': 'hot-coffee',
      'parent_id': null,
      'name_ar': 'قهوة ساخنة',
      'name_en': 'Hot Coffee',
      'description_ar': 'قهوة ساخنة بمشروبات',
      'description_en': 'Hot coffee, espresso based',
      'image_url': null,
      'icon_key': 'hot_coffee',
      'sort_order': 1,
      'is_active': true,
    };

    test('reads the row and resolves an icon key', () {
      final c = CategoryModel.fromJson(categoryRow);
      expect(c.id, categoryRow['id']);
      expect(c.slug, 'hot-coffee');
      expect(c.iconKey, 'hot_coffee');
      expect(c.icon, isNotNull);
      expect(c.sortOrder, 1);
    });

    test('label follows the app language', () {
      final c = CategoryModel.fromJson(categoryRow);
      expect(c.label, 'قهوة ساخنة');
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(c.label, 'Hot Coffee');
    });

    test('an unknown icon_key yields a neutral icon, never a crash', () {
      final c = CategoryModel.fromJson({
        ...categoryRow,
        'icon_key': 'a_category_added_tomorrow',
      });
      expect(c.icon, Icons.category_outlined);
    });

    test('a null icon_key does not break rendering', () {
      final c = CategoryModel.fromJson({...categoryRow, 'icon_key': null});
      expect(c.label, isNotEmpty);
      expect(c.icon, isNotNull);
    });

    test('supports sub-categories through parent_id', () {
      final parent = CategoryModel.fromJson(categoryRow);
      final child = CategoryModel.fromJson({
        ...categoryRow,
        'id': 'child-1',
        'slug': 'espresso',
        'parent_id': categoryRow['id'],
      });
      expect(child.parentId, parent.id);
    });
  });

  group('AppLocale', () {
    test('switches locale and persists the selection', () async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(AppLocale.instance.isArabic, isTrue);
      expect(AppLocale.instance.textDirection, TextDirection.rtl);
      await AppLocale.instance.toggle();
      expect(AppLocale.instance.isArabic, isFalse);
      expect(AppLocale.instance.textDirection, TextDirection.ltr);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language'), 'en');
    });

    test('parses a language code defensively', () {
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('en-US'), AppLanguage.english);
      expect(AppLanguage.fromCode('ar'), AppLanguage.arabic);
      expect(AppLanguage.fromCode(null), AppLanguage.arabic);
      expect(AppLanguage.fromCode('fr'), AppLanguage.arabic);
    });
  });

  test('payment method label follows the selected language', () {
    final method = PaymentMethodModel.fromDatabase({
      'id': 'cash',
      'name_ar': 'الدفع عند الاستلام',
      'name_en': 'Cash on Delivery',
      'code': 'cash',
    });

    AppLocale.instance.debugSet(AppLanguage.english);
    expect(method.label, 'Cash on Delivery');
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(method.label, 'الدفع عند الاستلام');
  });

  test('branch address follows the selected language', () {
    final branch = Branch.fromDatabase({
      'id': 'branch-1',
      'code': 'MAIN',
      'name_ar': 'الفرع الرئيسي',
      'name_en': 'Main Branch',
      'address': 'شارع الملك فهد، العليا، الرياض',
      'address_ar': 'شارع الملك فهد، العليا، الرياض',
      'address_en': 'King Fahd Road, Olaya, Riyadh',
    });

    AppLocale.instance.debugSet(AppLanguage.english);
    expect(branch.name, 'Main Branch');
    expect(branch.address, 'King Fahd Road, Olaya, Riyadh');
    AppLocale.instance.debugSet(AppLanguage.arabic);
    expect(branch.address, 'شارع الملك فهد، العليا، الرياض');
  });
}
