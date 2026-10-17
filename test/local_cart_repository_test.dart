import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';

/// The local cart is the offline mirror of the server cart. Its line identity
/// must match `orders.cart_items.options_key`: (product, note, sorted option
/// value ids). These tests pin that contract so a repeated add never duplicates
/// a line and two configurations never collapse into one.
void main() {
  const storageKey = 'cart_v1_local';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<List<dynamic>> storedLines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <dynamic>[];
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> add({
    required LocalCartRepository repo,
    String productId = 'p1',
    int quantity = 1,
    String note = '',
    List<String> optionValueIds = const [],
    double unitPrice = 10,
    String? bundleId,
  }) => repo.addItem(
    productId: productId,
    quantity: quantity,
    note: note,
    optionValueIds: optionValueIds,
    unitPrice: unitPrice,
    bundleId: bundleId,
  );

  test('1. same product with the same options adds to the quantity', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, quantity: 2, optionValueIds: ['a', 'b']);
    await add(repo: repo, quantity: 3, optionValueIds: ['a', 'b']);

    final lines = await storedLines();
    expect(lines, hasLength(1));
    expect(lines.single['quantity'], 5);
  });

  test('2. same product with different options stays a separate line', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, optionValueIds: ['a']);
    await add(repo: repo, optionValueIds: ['b']);

    final lines = await storedLines();
    expect(lines, hasLength(2));
    expect(lines.map((line) => line['quantity']).toList(), [1, 1]);
  });

  test('3. same product with different notes stays a separate line', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, note: 'Large');
    await add(repo: repo, note: 'Small');

    final lines = await storedLines();
    expect(lines, hasLength(2));
  });

  test('4. option order does not create a duplicate', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, quantity: 1, optionValueIds: ['b', 'a']);
    await add(repo: repo, quantity: 1, optionValueIds: ['a', 'b']);

    final lines = await storedLines();
    expect(lines, hasLength(1));
    expect(lines.single['quantity'], 2);
    // The stored order is canonical, not the first-seen order.
    expect(lines.single['optionValueIds'], ['a', 'b']);
  });

  test('5. empty and whitespace option ids are ignored in the identity',
      () async {
    final repo = LocalCartRepository();
    await add(repo: repo, optionValueIds: ['a', '', '  ']);
    await add(repo: repo, optionValueIds: ['a']);

    final lines = await storedLines();
    expect(lines, hasLength(1));
    expect(lines.single['quantity'], 2);
    expect(lines.single['optionValueIds'], ['a']);
  });

  test('6. repeating the same add never creates duplicates', () async {
    final repo = LocalCartRepository();
    for (var i = 0; i < 4; i++) {
      await add(repo: repo, note: 'Large', optionValueIds: ['a', 'b']);
    }

    final lines = await storedLines();
    expect(lines, hasLength(1));
    expect(lines.single['quantity'], 4);
  });

  test('7. merge quantity clamps at 99', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, quantity: 60, optionValueIds: ['a']);
    await add(repo: repo, quantity: 60, optionValueIds: ['a']);

    final lines = await storedLines();
    expect(lines.single['quantity'], 99);
  });

  test('8. a re-add refreshes the price without changing the identity',
      () async {
    final repo = LocalCartRepository();
    await add(repo: repo, quantity: 1, optionValueIds: ['a'], unitPrice: 10);
    await add(repo: repo, quantity: 1, optionValueIds: ['a'], unitPrice: 15);

    final lines = await storedLines();
    expect(lines, hasLength(1));
    expect(lines.single['quantity'], 2);
    expect((lines.single['unitPrice'] as num).toDouble(), 15);
  });

  test('9. reload keeps distinct lines distinct', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, optionValueIds: ['a']);
    await add(repo: repo, optionValueIds: ['b']);

    // A fresh instance reading the same storage must not merge them.
    final reopened = LocalCartRepository();
    await add(repo: reopened, optionValueIds: ['a']);

    final lines = await storedLines();
    expect(lines, hasLength(2));
    final byOption = {
      for (final line in lines)
        (line['optionValueIds'] as List).join(','): line['quantity'],
    };
    expect(byOption['a'], 2);
    expect(byOption['b'], 1);
  });

  test('10. clearCart empties every line', () async {
    final repo = LocalCartRepository();
    await add(repo: repo, optionValueIds: ['a']);
    await add(repo: repo, optionValueIds: ['b']);
    await repo.clearCart();

    expect(await storedLines(), isEmpty);
  });

  test('optionsKey is order-insensitive and drops empties', () {
    expect(LocalCartRepository.optionsKey(['b', 'a', '']), 'a,b');
    expect(LocalCartRepository.optionsKey(['a', 'b']), 'a,b');
    expect(LocalCartRepository.optionsKey([]), '');
  });
}
