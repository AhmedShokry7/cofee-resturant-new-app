import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/cart/data/repositories/supabase_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

import 'support/fake_postgrest_server.dart';

/// Cross-device synchronisation of the cart.
///
/// Every case runs two independent sessions against one shared server, the
/// way two phones signed in with the same account behave. The second session
/// starts with an empty device cache, so a line it can show can only have
/// come from the server.
void main() {
  const branch = 'branch-1';

  late FakePostgrestServer server;

  setUp(() async {
    server = await FakePostgrestServer.start();
    server.users['customer.a@test.local'] = 'user-a';
    server.users['customer.b@test.local'] = 'user-b';
    server.productPrices['1'] = 25;
    server.productPrices['2'] = 40;
    server.productPrices['3'] = 35;
  });

  tearDown(() async => server.close());

  Future<SupabaseClient> signedIn(String email) async {
    final client = SupabaseClient(server.url, 'test-key');
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(email: email, password: 'secret');
    return client;
  }

  Future<CartCubit> device(String email, {String? userId}) async {
    final client = await signedIn(email);
    final cubit = CartCubit(
      cartRepository: SupabaseCartRepository(client: client),
      catalogRepository: MockProductRepository(),
      branchId: branch,
      userIdProvider: () => userId ?? client.auth.currentUser!.id,
    );
    addTearDown(cubit.close);
    await cubit.settled;
    return cubit;
  }

  const latte = ProductModel(
    id: '3',
    name: 'Latte',
    category: 'Hot Coffee',
    description: 'd',
    price: 35,
    image: 'x',
  );

  test(
    'a line added on one device is stored on the server, not only on screen',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = await device('customer.a@test.local');

      first.add(latte, quantity: 2, note: 'Large', optionValueIds: ['large']);
      await first.flushServerSync();

      // The server holds the line, with the quantity and the options.
      expect(server.cartItems, hasLength(1));
      final stored = server.cartItems.values.single;
      expect(stored['product_id'], '3');
      expect(stored['quantity'], 2);
      expect(stored['note'], 'Large');
      expect(
        server.cartItemOptions.values.map((row) => row['option_value_id']),
        ['large'],
      );
    },
  );

  test('a quantity change reaches the server', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');

    first.add(latte, quantity: 1);
    await first.flushServerSync();
    first.incrementLine(first.state.items.single.lineId);
    await first.flushServerSync();

    expect(server.cartItems.values.single['quantity'], 2);
  });

  test('a line added on one device shows up on the other one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    first.add(latte, quantity: 3, note: 'Large', optionValueIds: ['large']);
    await first.flushServerSync();

    // The second device starts with an empty device cache.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final second = await device('customer.a@test.local');

    expect(second.state.items, hasLength(1));
    final line = second.state.items.single;
    expect(line.product.id, '3');
    expect(line.quantity, 3);
    expect(line.note, 'Large');
    expect(line.optionValueIds, ['large']);
  });

  test('a line removed on one device disappears on the other one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    first.add(latte, quantity: 1);
    await first.flushServerSync();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final second = await device('customer.a@test.local');
    expect(second.state.items, hasLength(1));

    first.removeLine(first.state.items.single.lineId);
    await first.flushServerSync();
    expect(server.cartItems, isEmpty);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final third = await device('customer.a@test.local');
    expect(third.state.items, isEmpty);
  });

  test('an emptied cart reaches the server', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    first.add(latte, quantity: 1);
    await first.flushServerSync();
    expect(server.cartItems, hasLength(1));

    first.clear();
    await first.flushServerSync();

    expect(server.cartItems, isEmpty);
  });

  test('a repeated add never duplicates the line', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');

    first.add(latte, quantity: 1, optionValueIds: ['large']);
    await first.flushServerSync();
    first.add(latte, quantity: 2, optionValueIds: ['large']);
    await first.flushServerSync();

    expect(server.cartItems, hasLength(1));
    expect(server.cartItems.values.single['quantity'], 3);
    expect(
      server.cartItemOptions.values.where(
        (row) => row['cart_item_id'] == server.cartItems.values.single['id'],
      ),
      hasLength(1),
    );
  });

  test(
    'a refused write is reported and never presented as a saved cart',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = await device('customer.a@test.local');

      server.failNextWriteWithStatus = 500;
      first.add(latte, quantity: 1);
      await first.flushServerSync();

      expect(first.state.error, isNotNull);
      expect(server.cartItems, isEmpty);

      // The failed change is kept on the device and pushed again later.
      server.failNextWriteWithStatus = null;
      await first.flushServerSync();
      expect(server.cartItems, hasLength(1));
      expect(first.state.error, isNull);
    },
  );

  test(
    'a server that cannot be read keeps the device cart and says so',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = await device('customer.a@test.local');
      first.add(latte, quantity: 1);
      await first.flushServerSync();

      // The next read fails: the customer keeps the lines and is told.
      server.failNextReadWithStatus = 500;
      final second = await device('customer.a@test.local');

      expect(second.state.error, isNotNull);
      expect(second.state.items, hasLength(1));
    },
  );

  test('one account never sees or touches the cart of another', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final a = await device('customer.a@test.local');
    a.add(latte, quantity: 1);
    await a.flushServerSync();
    expect(server.cartItems, hasLength(1));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final b = await device('customer.b@test.local');
    expect(b.state.items, isEmpty);

    // B's own cart is a different cart.
    b.add(latte, quantity: 5);
    await b.flushServerSync();

    final carts = server.carts.values.toList();
    expect(carts, hasLength(2));
    final aCart = carts.firstWhere((cart) => cart['user_id'] == 'user-a');
    final bCart = carts.firstWhere((cart) => cart['user_id'] == 'user-b');
    final aLines = server.cartItems.values
        .where((row) => row['cart_id'] == aCart['id'])
        .toList();
    final bLines = server.cartItems.values
        .where((row) => row['cart_id'] == bCart['id'])
        .toList();
    expect(aLines.single['quantity'], 1);
    expect(bLines.single['quantity'], 5);
  });

  test('signing out does not delete the server cart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    first.add(latte, quantity: 1);
    await first.flushServerSync();

    // The session ends. The server keeps the cart for the next sign-in.
    final client = SupabaseClient(server.url, 'test-key');
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'customer.a@test.local',
      password: 'secret',
    );
    await client.auth.signOut();

    expect(server.cartItems, hasLength(1));
  });

  test(
    'a guest cart is adopted into the account and reaches the server',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        // The guest cart is on the device before anybody signs in.
        CartCubit.storageKeyFor(null): '[{"productId":"3","quantity":2}]',
      });

      final first = await device('customer.a@test.local');
      await first.flushServerSync();

      expect(first.state.items, hasLength(1));
      expect(first.state.items.single.product.id, '3');
      expect(first.state.items.single.quantity, 2);
      expect(server.cartItems, hasLength(1));
      expect(server.cartItems.values.single['quantity'], 2);

      // The guest slot is empty afterwards, so a later sign-out starts empty.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CartCubit.storageKeyFor(null)), '[]');
    },
  );

  test(
    'another branch keeps the lines and mirrors them into its server cart',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = await device('customer.a@test.local');
      first.add(latte, quantity: 1);
      await first.flushServerSync();

      await first.setBranch('branch-2');

      // The customer keeps the lines: the cart belongs to the customer.
      expect(first.state.items, hasLength(1));

      // The new branch has its own server cart, holding the same lines.
      final carts = server.carts.values.toList();
      expect(carts, hasLength(2));
      final otherCart = carts.firstWhere(
        (cart) => cart['branch_id'] == 'branch-2',
      );
      final lines = server.cartItems.values
          .where((row) => row['cart_id'] == otherCart['id'])
          .toList();
      expect(lines, hasLength(1));
      expect(lines.single['product_id'], '3');
    },
  );

  test('a bundle keeps its wrapper on the device that added it', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');

    first.addBundle(
      bundleId: 'bundle-1',
      title: 'Morning Duo',
      image: 'x',
      price: 48,
      components: const [
        CartBundleComponent(productId: '1', quantity: 1, unitPrice: 25),
        CartBundleComponent(productId: '12', quantity: 1, unitPrice: 23),
      ],
    );
    await first.flushServerSync();

    // The server stores the bundle as its component lines.
    expect(server.cartItems, hasLength(2));

    // The device that added it still sees one bundle line.
    await first.load();
    expect(first.state.items, hasLength(1));
    expect(first.state.items.single.isBundle, isTrue);
    expect(first.state.items.single.bundleId, 'bundle-1');
  });

  test('a standalone line is never absorbed into a bundle of the same product',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');

    // Standalone first, then the bundle, so the standalone row comes first in
    // the server cart and a merge that ignores the bundle would take it.
    first.add(latte, quantity: 3);
    await first.flushServerSync();
    first.addBundle(
      bundleId: 'bundle-1',
      title: 'Morning Duo',
      image: 'x',
      price: 48,
      components: const [
        CartBundleComponent(productId: '3', quantity: 1, unitPrice: 35),
      ],
    );
    await first.flushServerSync();

    final second = await device('customer.a@test.local');
    final bundle = second.state.items.firstWhere((item) => item.isBundle);
    final standalone = second.state.items.firstWhere((item) => !item.isBundle);

    expect(bundle.bundleId, 'bundle-1');
    expect(bundle.quantity, 1);
    expect(standalone.product.id, '3');
    expect(standalone.quantity, 3);
    expect(standalone.bundleId, isNull);
  });

  test('component lines without a cached wrapper keep their bundle identity',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    first.addBundle(
      bundleId: 'bundle-1',
      title: 'Morning Duo',
      image: 'x',
      price: 48,
      components: const [
        CartBundleComponent(productId: '1', quantity: 1, unitPrice: 25),
        CartBundleComponent(productId: '12', quantity: 1, unitPrice: 23),
      ],
    );
    await first.flushServerSync();

    // A fresh device has no bundle wrapper cached, so the two server lines
    // show separately; their bundle identity must survive the next write.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final second = await device('customer.a@test.local');
    expect(second.state.items, hasLength(2));
    expect(
      second.state.items.map((item) => item.bundleId),
      everyElement('bundle-1'),
    );

    second.incrementLine(second.state.items.first.lineId);
    await second.flushServerSync();

    final rows = server.cartItems.values.toList();
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['bundle_id']), everyElement('bundle-1'));
  });
}
