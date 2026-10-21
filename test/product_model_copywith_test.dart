import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// Contract of `ProductModel.copyWith`.
///
/// The catalogue read builds a product with every field the database sent,
/// then copies it to attach the gallery and the branch price. A field that
/// `copyWith` does not carry is silently lost on that copy, which is how the
/// category slug, the preparation time, the SKU and the related product ids
/// used to disappear from every product the app showed.
///
/// The contract these tests pin down:
///   * a field that is not mentioned keeps its value (null means "keep");
///   * a field that is mentioned is updated;
///   * a nullable field cannot be cleared to null, and a list keeps the
///     identity of the original list — the same rules the rest of the method
///     already followed for `slug`, `oldPrice` and `imageUrls`.
void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  ProductModel fullProduct() => const ProductModel(
        id: 'p1',
        name: 'Latte',
        category: 'Hot Coffee',
        description: 'Espresso with steamed milk',
        price: 20,
        image: 'https://img.test/p1.png',
        nameAr: 'لاتيه',
        nameEn: 'Latte',
        categoryAr: 'قهوة ساخنة',
        categoryEn: 'Hot Coffee',
        categoryId: 'c1',
        categorySlug: 'hot-coffee',
        slug: 'latte',
        sku: 'CF-001',
        descriptionAr: 'وصف',
        descriptionEn: 'Description',
        oldPrice: 25,
        isFeatured: true,
        prepMinutes: 4,
        imageUrls: <String>['https://img.test/p1-a.png'],
        isPrimaryImageAvailable: true,
        primaryImageUrl: 'https://img.test/p1-a.png',
        relatedProductIds: <String>['p2', 'p3'],
      );

  group('the four fields copyWith used to drop', () {
    test('categorySlug survives a copy that changes something else', () {
      final copied = fullProduct().copyWith(price: 15);
      expect(copied.categorySlug, 'hot-coffee');
    });

    test('prepMinutes survives a copy that changes something else', () {
      final copied = fullProduct().copyWith(price: 15);
      expect(copied.prepMinutes, 4);
    });

    test('relatedProductIds survives a copy that changes something else', () {
      final copied = fullProduct().copyWith(price: 15);
      expect(copied.relatedProductIds, <String>['p2', 'p3']);
    });

    test('sku survives a copy that changes something else', () {
      final copied = fullProduct().copyWith(price: 15);
      expect(copied.sku, 'CF-001');
    });

    test('all four survive a copy that only touches the gallery', () {
      final copied = fullProduct().copyWith(
        imageUrls: <String>['https://img.test/p1-b.png'],
        primaryImageUrl: 'https://img.test/p1-b.png',
        isPrimaryImageAvailable: true,
      );
      expect(copied.categorySlug, 'hot-coffee');
      expect(copied.prepMinutes, 4);
      expect(copied.sku, 'CF-001');
      expect(copied.relatedProductIds, <String>['p2', 'p3']);
    });
  });

  group('new values are applied', () {
    test('categorySlug can be replaced', () {
      final copied = fullProduct().copyWith(categorySlug: 'cold-drinks');
      expect(copied.categorySlug, 'cold-drinks');
    });

    test('prepMinutes can be replaced', () {
      final copied = fullProduct().copyWith(prepMinutes: 9);
      expect(copied.prepMinutes, 9);
    });

    test('sku can be replaced', () {
      final copied = fullProduct().copyWith(sku: 'CF-999');
      expect(copied.sku, 'CF-999');
    });

    test('relatedProductIds can be replaced', () {
      final copied = fullProduct().copyWith(relatedProductIds: <String>['p9']);
      expect(copied.relatedProductIds, <String>['p9']);
    });
  });

  group('the optional-value and list contract is unchanged', () {
    test('null keeps the current value, as it does for every other field', () {
      final copied = fullProduct().copyWith(
        categorySlug: null,
        prepMinutes: null,
        sku: null,
        relatedProductIds: null,
      );
      expect(copied.categorySlug, 'hot-coffee');
      expect(copied.prepMinutes, 4);
      expect(copied.sku, 'CF-001');
      expect(copied.relatedProductIds, <String>['p2', 'p3']);
    });

    test('an empty list is a value, not a missing argument', () {
      final copied = fullProduct().copyWith(relatedProductIds: const <String>[]);
      expect(copied.relatedProductIds, isEmpty);
    });

    test('an empty string is a value, not a missing argument', () {
      final copied = fullProduct().copyWith(categorySlug: '');
      expect(copied.categorySlug, isEmpty);
    });

    test('a list is carried over by reference, like imageUrls already is', () {
      final original = fullProduct();
      final copied = original.copyWith(price: 15);
      expect(identical(copied.relatedProductIds, original.relatedProductIds),
          isTrue,
          reason: 'copyWith must not start copying lists it never copied');
    });

    test('a product without the optional values keeps them absent', () {
      const bare = ProductModel(
        id: 'p2',
        price: 10,
        image: '',
      );
      final copied = bare.copyWith(price: 12);
      expect(copied.categorySlug, isEmpty);
      expect(copied.prepMinutes, isNull);
      expect(copied.sku, isNull);
      expect(copied.relatedProductIds, isEmpty);
    });
  });

  group('the other fields behave exactly as before', () {
    test('a copy keeps every field it was not asked to change', () {
      final original = fullProduct();
      final copied = original.copyWith(price: 15);

      expect(copied.id, original.id);
      expect(copied.nameAr, original.nameAr);
      expect(copied.nameEn, original.nameEn);
      expect(copied.categoryAr, original.categoryAr);
      expect(copied.categoryEn, original.categoryEn);
      expect(copied.categoryId, original.categoryId);
      expect(copied.descriptionAr, original.descriptionAr);
      expect(copied.descriptionEn, original.descriptionEn);
      expect(copied.slug, original.slug);
      expect(copied.oldPrice, original.oldPrice);
      expect(copied.image, original.image);
      expect(copied.isFeatured, original.isFeatured);
      expect(copied.imageUrls, original.imageUrls);
      expect(copied.isPrimaryImageAvailable, original.isPrimaryImageAvailable);
      expect(copied.primaryImageUrl, original.primaryImageUrl);
      expect(copied.name, original.name);
      expect(copied.category, original.category);
      expect(copied.description, original.description);
    });

    test('a copy can still change price, image, the gallery and the flags', () {
      final copied = fullProduct().copyWith(
        price: 33,
        image: 'https://img.test/other.png',
        imageUrls: const <String>['https://img.test/x.png'],
        isFeatured: false,
      );
      expect(copied.price, 33);
      expect(copied.image, 'https://img.test/other.png');
      expect(copied.imageUrls, <String>['https://img.test/x.png']);
      expect(copied.isFeatured, isFalse);
    });

    test('the legacy name is only a fallback, so it never overrides the pair',
        () {
      // `name` feeds the single-language fallback. A product that carries
      // both name_ar and name_en always shows those, which is why passing
      // `name` to copyWith does not rename it. That is the existing
      // behaviour of the model and this test pins it down.
      final copied = fullProduct().copyWith(name: 'Iced Latte');
      expect(copied.name, 'Latte');
      expect(copied.nameEn, 'Latte');

      const monolingual = ProductModel(
        id: 'p3',
        name: 'Latte',
        price: 20,
        image: '',
      );
      expect(monolingual.copyWith(name: 'Iced Latte').name, 'Iced Latte');
    });
  });
}
