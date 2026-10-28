import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_records.dart';
import 'package:admin_app/features/catalog/presentation/widgets/category_records.dart';

/// سجل واحد للقاعدة، نسختان تقرآن منه: الفئة والباندل لهما الحقول الأربعة
/// نفسها، فأي استثناء يسري على واحدة يسري على الأخرى.
const _items =
    <({String id, String nameAr, String nameEn, String? dAr, String? dEn})>[
      (
        id: 'a',
        nameAr: 'قهوة مختصة',
        nameEn: 'Specialty Coffee',
        dAr: null,
        dEn: null,
      ),
      (
        id: 'b',
        nameAr: 'حلويات',
        nameEn: 'Desserts',
        dAr: 'كيك طازج',
        dEn: null,
      ),
      (
        id: 'c',
        nameAr: 'عصائر',
        nameEn: 'Juices',
        dAr: null,
        dEn: 'Fresh squeezed',
      ),
      (id: 'd', nameAr: 'مياه', nameEn: 'Water', dAr: null, dEn: null),
    ];

final _categories = _items
    .map(
      (item) => AdminCategory(
        id: item.id,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        descriptionAr: item.dAr,
        descriptionEn: item.dEn,
      ),
    )
    .toList();

final _bundles = _items
    .map(
      (item) => AdminBundle(
        id: item.id,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        descriptionAr: item.dAr,
        descriptionEn: item.dEn,
      ),
    )
    .toList();

void main() {
  for (final (query, expected) in <(String, List<String>)>[
    ('', const ['a', 'b', 'c', 'd']),
    ('   ', const ['a', 'b', 'c', 'd']),
    ('قهوة', const ['a']),
    ('COFF', const ['a']),
    ('Juice', const ['c']),
    ('كيك', const ['b']),
    ('squeezed', const ['c']),
    ('pizza', const <String>[]),
  ]) {
    test('«$query» filters categories and bundles alike', () {
      final categories = filterCategories(
        _categories,
        query,
      ).map((c) => c.id).toList();
      final bundles = filterBundles(_bundles, query).map((b) => b.id).toList();

      expect(categories, expected);
      expect(bundles, expected);
    });
  }
}
