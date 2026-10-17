import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _placedRow = <String, dynamic>{
  'order_id': 'order-1',
  'order_number': 'ORD-1',
  'subtotal': 20,
  'discount_total': 0,
  'delivery_fee': 0,
  'tax_total': 0,
  'grand_total': 20,
  'points_earned': 2,
  'reused_existing_order': false,
};

void main() {
  late SupabaseClient client;

  setUp(() {
    client = SupabaseClient('http://localhost:54321', 'test-key');
  });

  tearDown(() => client.dispose());

  SupabaseOrdersRepository repositoryWith(
    Future<dynamic> Function(String, Map<String, dynamic>) rpc,
  ) => SupabaseOrdersRepository(
    client: client,
    rpc: rpc,
    userIdProvider: () => 'user-1',
  );

  test('empty cart replacement is a single atomic RPC', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final repository = repositoryWith((name, params) async {
      calls.add((name, params));
      return [
        {'cart_id': 'cart-1', 'item_count': 0, 'subtotal': 0},
      ];
    });

    await repository.syncCart(branchId: 'branch-1', lines: const []);

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'replace_cart');
    expect(calls.single.$2['p_lines'], isEmpty);
  });

  test('replacement sends distinct options and no client prices', () async {
    late Map<String, dynamic> sent;
    final repository = repositoryWith((name, params) async {
      expect(name, 'replace_cart');
      sent = params;
      return [
        {'cart_id': 'cart-1', 'item_count': 2, 'subtotal': 20},
      ];
    });

    await repository.syncCart(
      branchId: 'branch-1',
      lines: const [
        PlaceOrderLine(
          productId: 'product-1',
          quantity: 1,
          optionValueIds: ['option-small'],
          bundleId: 'bundle-1',
        ),
        PlaceOrderLine(
          productId: 'product-1',
          quantity: 1,
          optionValueIds: ['option-large'],
        ),
      ],
    );

    final lines = sent['p_lines'] as List;
    expect(lines, hasLength(2));
    expect(lines[0]['option_value_ids'], ['option-small']);
    expect(lines[0]['bundle_id'], 'bundle-1');
    expect(lines[1]['option_value_ids'], ['option-large']);
    expect(lines.every((line) => !line.containsKey('unit_price')), isTrue);
  });

  test(
    'replacement failure stops after the single server transaction',
    () async {
      var calls = 0;
      final repository = repositoryWith((name, params) async {
        calls++;
        throw StateError('server rejected a cart line');
      });

      await expectLater(
        repository.syncCart(
          branchId: 'branch-1',
          lines: const [PlaceOrderLine(productId: 'bad', quantity: 1)],
        ),
        throwsA(isA<StateError>()),
      );
      expect(calls, 1);
    },
  );

  test('order submission sends the stable key and cart in one RPC', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final repository = repositoryWith((name, params) async {
      calls.add((name, params));
      return [_placedRow];
    });

    await repository.placeOrder(
      branchId: 'branch-1',
      lines: const [PlaceOrderLine(productId: 'product-1', quantity: 2)],
      idempotencyKey: 'attempt-1',
    );

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'place_order_with_lines');
    expect(calls.single.$2['p_idempotency_key'], 'attempt-1');
    expect(calls.single.$2['p_lines'].single['product_id'], 'product-1');
  });

  test(
    'parallel retries send the same key for server-side serialization',
    () async {
      final pending = Completer<dynamic>();
      final keys = <String>[];
      final repository = repositoryWith((name, params) {
        expect(name, 'place_order_with_lines');
        keys.add(params['p_idempotency_key'] as String);
        return pending.future;
      });
      Future<PlacedOrder> submit() => repository.placeOrder(
        branchId: 'branch-1',
        lines: const [PlaceOrderLine(productId: 'product-1', quantity: 1)],
        idempotencyKey: 'same-attempt',
      );

      final first = submit();
      final second = submit();
      expect(keys, ['same-attempt', 'same-attempt']);
      pending.complete([_placedRow]);
      final results = await Future.wait([first, second]);
      expect(results.map((order) => order.orderId), ['order-1', 'order-1']);
    },
  );
}
