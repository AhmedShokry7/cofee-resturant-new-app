// The cart's line rules, tested without a cubit, a repository or storage.
//
// These functions decide what the server is told a cart contains, and the
// checkout prices an order from the same expansion. A bundle that expands
// wrongly is a bundle that gets charged at the wrong price, so the rules are
// pinned here rather than through a screen.
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

ProductModel _product(String id) =>
    ProductModel(id: id, name: id, price: 25, image: 'assets/images/p.png');

CartItem _item(String id, {int quantity = 1, String note = ''}) =>
    CartItem(product: _product(id), quantity: quantity, note: note);

/// A bundle sold as one line: two components, two of each per bundle.
CartItem _bundle(int quantity) => CartItem(
  product: _product('bundle-1'),
  quantity: quantity,
  bundleId: 'bundle-1',
  bundleComponents: const [
    CartBundleComponent(productId: 'p1', quantity: 1, unitPrice: 20),
    CartBundleComponent(productId: 'p2', quantity: 2, unitPrice: 10),
  ],
);

void main() {
  group('serverLinesForItems', () {
    test('a standalone line is sent as it is', () {
      final lines = serverLinesForItems([
        _item('p1', quantity: 3, note: 'iced'),
      ]);

      expect(lines, hasLength(1));
      expect(lines.single.productId, 'p1');
      expect(lines.single.quantity, 3);
      expect(lines.single.note, 'iced');
      expect(lines.single.bundleId, isNull);
    });

    test(
      'a bundle becomes one server line per component, scaled by the order',
      () {
        final lines = serverLinesForItems([_bundle(2)]);

        expect(lines.map((l) => l.productId), ['p1', 'p2']);
        // The bundle is ordered twice, so its second component counts four.
        expect(lines.map((l) => l.quantity), [2, 4]);
        expect(lines.every((l) => l.bundleId == 'bundle-1'), isTrue);
      },
    );

    test(
      'a component line whose wrapper is gone is still sent, with its bundle',
      () {
        final orphan = CartItem(
          product: _product('p1'),
          quantity: 1,
          bundleId: 'bundle-gone',
        );

        expect(serverLinesForItems([orphan]), hasLength(1));
        expect(serverLinesForItems([orphan]).single.bundleId, 'bundle-gone');
      },
    );
  });

  group('serverLinesForEntries', () {
    test(
      'a stored entry keeps the quantity, note and options it was saved with',
      () {
        final lines = serverLinesForEntries([
          {
            'productId': 'p1',
            'quantity': 4,
            'note': 'no sugar',
            'optionValueIds': ['o2', 'o1'],
          },
        ]);

        expect(lines.single.quantity, 4);
        expect(lines.single.note, 'no sugar');
        // The ids are canonicalised, so a stored order does not create a second
        // line for the same configuration.
        expect(lines.single.optionValueIds, ['o1', 'o2']);
      },
    );

    test('a stored entry with nothing in it still reads as one item', () {
      final lines = serverLinesForEntries([
        {'productId': 'p1'},
      ]);

      expect(lines.single.quantity, 1);
      expect(lines.single.note, isEmpty);
    });

    test('a stored bundle expands into its component lines', () {
      final lines = serverLinesForEntries([
        {
          'productId': 'bundle-1',
          'quantity': 2,
          'isBundle': true,
          'bundleId': 'bundle-1',
          'bundleComponents': [
            {'productId': 'p1', 'quantity': 1, 'unitPrice': 20},
            {'productId': 'p2', 'quantity': 2, 'unitPrice': 10},
          ],
        },
      ]);

      expect(lines.map((l) => l.quantity), [2, 4]);
    });

    test(
      'a stored entry that says bundle but names no components is dropped',
      () {
        final lines = serverLinesForEntries([
          {'productId': 'bundle-1', 'isBundle': true},
        ]);

        expect(lines, isEmpty);
      },
    );
  });

  group('mergeServerLines', () {
    test('a bundle is re-attached to the component lines the server kept', () {
      final cached = [
        {
          'productId': 'bundle-1',
          'quantity': 9,
          'isBundle': true,
          'bundleId': 'bundle-1',
          'bundleComponents': [
            {'productId': 'p1', 'quantity': 1, 'unitPrice': 20},
            {'productId': 'p2', 'quantity': 2, 'unitPrice': 10},
          ],
        },
      ];
      final server = [
        const CartLine(productId: 'p1', quantity: 3, bundleId: 'bundle-1'),
        const CartLine(productId: 'p2', quantity: 6, bundleId: 'bundle-1'),
      ];

      final merged = mergeServerLines(server, cached);

      // The server holds three bundles' worth, not the nine the device asked for.
      expect(merged, hasLength(1));
      expect(merged.single['quantity'], 3);
    });

    test('the merged bundle is priced from what the server charged, not the device', () {
      final cached = [
        {
          'productId': 'bundle-1',
          'quantity': 1,
          'isBundle': true,
          'bundleId': 'bundle-1',
          'bundlePrice': 40.0,
          'unitPrice': 40.0,
          'bundleComponents': [
            {'productId': 'p1', 'quantity': 1, 'unitPrice': 20},
            {'productId': 'p2', 'quantity': 2, 'unitPrice': 10},
          ],
        },
      ];
      // The server prices each component at its share of the bundle, so the
      // wrapper's price is the sum of those shares for one bundle.
      final server = [
        const CartLine(
          productId: 'p1',
          quantity: 1,
          unitPrice: 11,
          bundleId: 'bundle-1',
        ),
        const CartLine(
          productId: 'p2',
          quantity: 2,
          unitPrice: 7,
          bundleId: 'bundle-1',
        ),
      ];

      final merged = mergeServerLines(server, cached);

      expect(merged.single['quantity'], 1);
      expect(merged.single['unitPrice'], 25);
      expect(merged.single['bundlePrice'], 25);
    });

    test(
      'an unpriced server cart leaves the device price in the bundle line',
      () {
        final cached = [
          {
            'productId': 'bundle-1',
            'quantity': 1,
            'isBundle': true,
            'bundleId': 'bundle-1',
            'bundlePrice': 40.0,
            'unitPrice': 40.0,
            'bundleComponents': [
              {'productId': 'p1', 'quantity': 1, 'unitPrice': 20},
              {'productId': 'p2', 'quantity': 2, 'unitPrice': 10},
            ],
          },
        ];
        final server = [
          const CartLine(productId: 'p1', quantity: 1, bundleId: 'bundle-1'),
          const CartLine(productId: 'p2', quantity: 2, bundleId: 'bundle-1'),
        ];

        final merged = mergeServerLines(server, cached);

        // Nothing was invented: the line keeps the only price either side has,
        // and the next priced read replaces it.
        expect(merged.single['unitPrice'], 40.0);
        expect(merged.single['bundlePrice'], 40.0);
      },
    );

    test(
      'a bundle the server does not hold completely stays as server lines',
      () {
        final cached = [
          {
            'productId': 'bundle-1',
            'quantity': 1,
            'isBundle': true,
            'bundleId': 'bundle-1',
            'bundleComponents': [
              {'productId': 'p1', 'quantity': 1, 'unitPrice': 20},
              {'productId': 'p2', 'quantity': 1, 'unitPrice': 10},
            ],
          },
        ];
        final server = [
          const CartLine(productId: 'p1', quantity: 1, bundleId: 'bundle-1'),
        ];

        final merged = mergeServerLines(server, cached);

        expect(merged, hasLength(1));
        expect(merged.single['productId'], 'p1');
        expect(merged.single.containsKey('isBundle'), isFalse);
      },
    );

    test(
      'a standalone line of the same product is never pulled into the bundle',
      () {
        final cached = [
          {
            'productId': 'bundle-1',
            'quantity': 1,
            'isBundle': true,
            'bundleId': 'bundle-1',
            'bundleComponents': [
              {'productId': 'p1', 'quantity': 1, 'unitPrice': 20},
            ],
          },
        ];
        final server = [
          const CartLine(productId: 'p1', quantity: 1),
          const CartLine(productId: 'p1', quantity: 1, bundleId: 'bundle-1'),
        ];

        final merged = mergeServerLines(server, cached);

        expect(merged, hasLength(2));
        expect(
          merged.where((entry) => entry['bundleId'] == null),
          hasLength(1),
        );
      },
    );

    test('components that do not cover a single bundle make no bundle', () {
      final cached = [
        {
          'productId': 'bundle-1',
          'quantity': 1,
          'isBundle': true,
          'bundleId': 'bundle-1',
          'bundleComponents': [
            {'productId': 'p1', 'quantity': 5, 'unitPrice': 20},
          ],
        },
      ];
      final server = [
        const CartLine(productId: 'p1', quantity: 2, bundleId: 'bundle-1'),
      ];

      final merged = mergeServerLines(server, cached);

      // Clamping this to one would sell a bundle the server cannot price.
      expect(merged.single.containsKey('isBundle'), isFalse);
      expect(merged.single['quantity'], 2);
    });
  });

  group('decodeCartEntries', () {
    test('a payload that is not a list reads as an empty cart', () {
      expect(decodeCartEntries('{"productId":"p1"}'), isEmpty);
      expect(
        decodeCartEntries('[{"productId":"p1"}]').single['productId'],
        'p1',
      );
    });
  });

  group('sameOptionIds', () {
    test('the same choices in a different order are not the same line', () {
      expect(sameOptionIds(const ['a', 'b'], const ['a', 'b']), isTrue);
      expect(sameOptionIds(const ['a', 'b'], const ['b', 'a']), isFalse);
      expect(sameOptionIds(const ['a'], const ['a', 'b']), isFalse);
    });
  });
}
