// The cart is asked about in its own words.
//
// The intent matcher read "شيل اللاتيه من السلة" as a request to place an
// order, so a customer asking to take something out was answered with
// "shall I confirm the order?". These tests pin the cart behaviour.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  late AssistantSnapshot snapshot;
  late String latteId;

  setUpAll(() async {
    await AssistantCatalog.load();
    snapshot = await AssistantSnapshot.load(
      catalog: const MockProductRepository(),
      activeOrders: () async => const <OrderItemModel>[],
    );
    latteId = snapshot.products
        .firstWhere((product) => product.name == 'Latte')
        .id;
  });

  AssistantAnswer ask(
    String query, {
    Set<String> cart = const {},
  }) =>
      AssistantEngine.answer(
        query,
        snapshot: snapshot,
        memory: AssistantMemory(replyArabic: true),
        now: DateTime.now(),
        cartProductIds: cart,
      );

  group('taking something out of the cart', () {
    test('is a removal, not an order', () {
      final answer = ask(
        'شيل اللاتيه من السلة',
        cart: {latteId},
      );

      expect(answer.topic, 'cart');
      expect(answer.actions, hasLength(1));
      expect(answer.actions.first.remove, isTrue);
      expect(answer.actions.first.productId, latteId);
      expect(answer.text, contains('شلت'));
    });

    test('says so when the product is not in the cart', () {
      final answer = ask('شيل اللاتيه من السلة');

      expect(answer.topic, 'cart');
      expect(answer.actions, isEmpty);
      expect(answer.text, contains('مش في السلة'));
    });

    test('asks which one when the product is not named', () {
      final answer = ask('شيل من السلة', cart: {latteId});

      expect(answer.topic, 'cart');
      expect(answer.actions, isEmpty);
      expect(answer.text, contains('أشيل إيه'));
    });
  });

  group('what is in the cart', () {
    test('an empty cart says so', () {
      final answer = ask('السلة فاضية؟');

      expect(answer.topic, 'cart');
      expect(answer.text, contains('فاضية'));
    });

    test('a full cart counts the items', () {
      final answer = ask('عندك كام حاجة في السلة', cart: {latteId});

      expect(answer.topic, 'cart');
      expect(answer.text, contains('1'));
      expect(answer.text, contains('Latte'));
    });
  });
}
