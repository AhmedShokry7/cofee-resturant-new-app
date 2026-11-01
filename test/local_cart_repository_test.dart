import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';

/// The offline stand-in for the server cart.
///
/// It has to answer "there is no server" rather than "the server cart is
/// empty": an empty answer would silently clear the customer's cart on every
/// load while the backend is unreachable.
void main() {
  test('the offline repository reports that there is no server cart', () async {
    const repository = LocalCartRepository();

    expect(await repository.fetchLines(branchId: 'branch-1'), isNull);
  });

  test('the offline repository accepts a write without a server', () async {
    const repository = LocalCartRepository();

    await repository.saveLines(
      branchId: 'branch-1',
      lines: const [CartLine(productId: 'p1', quantity: 2)],
    );
  });

  test('the canonical option order drops empties and is stable', () {
    expect(canonicalOptionIds(['b', 'a', '']), ['a', 'b']);
    expect(canonicalOptionIds(['a', 'b']), ['a', 'b']);
    expect(canonicalOptionIds([]), isEmpty);
    expect(canonicalOptionIds(['  ']), isEmpty);
  });

  test('a line never carries a price to the server', () {
    const line = CartLine(
      productId: 'p1',
      quantity: 2,
      note: 'Large',
      optionValueIds: ['a'],
      unitPrice: 42,
    );

    final payload = line.toServerPayload();
    expect(payload.containsKey('unit_price'), isFalse);
    expect(payload.containsKey('unitPrice'), isFalse);
    expect(payload['product_id'], 'p1');
    expect(payload['quantity'], 2);
    expect(payload['note'], 'Large');
    expect(payload['option_value_ids'], ['a']);
  });
}
