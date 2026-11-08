// The cart is only written after the customer explicitly authorises it, and a
// success line is only shown once the write actually landed.
//
// These tests drive the cubit the way the page does, with a fake cart layer in
// place of CartCubit, so they can see exactly what reached the cart and in what
// order the answer was emitted relative to the write.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

import 'support/mock_product_repository.dart';

class _NoOrders implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Stands in for CartCubit: records every write it is asked to perform and
/// answers with the result the test chooses.
class _FakeCart {
  final calls = <List<CartAction>>[];
  bool result = true;
  Object? error;

  Future<bool> call(List<CartAction> actions, AssistantSnapshot snapshot) async {
    calls.add(actions);
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  Future<AssistantCubit> openChat(_FakeCart cart) async {
    final cubit = AssistantCubit(
      catalog: const MockProductRepository(),
      orders: _NoOrders(),
      memoryStore: const NoAssistantMemoryStore(),
      retrieval: const NoRetrieval(),
      cartExecutor: cart.call,
    );
    addTearDown(cubit.close);
    await cubit.start();
    return cubit;
  }

  ChatMessage lastAnswer(AssistantCubit cubit) => cubit.state.messages.last;

  group('authorising a cart write', () {
    test('a confirmed order is written before it is announced', () async {
      final cart = _FakeCart();
      final cubit = await openChat(cart);

      await cubit.sendMessage('عايز اطلب لاتيه كبير');
      // The proposal is on screen, but nothing has reached the cart yet.
      expect(lastAnswer(cubit).sourceId, 'order-confirm');
      expect(cart.calls, isEmpty);

      await cubit.sendMessage('أيوه');

      // The explicit yes authorised exactly one write, and every action in it
      // carries that authority — the command alone is never enough.
      expect(cart.calls, hasLength(1));
      expect(cart.calls.single, isNotEmpty);
      expect(cart.calls.single.every((a) => a.approvedBy != null), isTrue);
      // The success line is shown only after the write landed.
      expect(lastAnswer(cubit).sourceId, 'order-confirmed');
      expect(lastAnswer(cubit).text, contains('السلة'));
    });

    test('a failed write is not announced as a success', () async {
      final cart = _FakeCart()..result = false;
      final cubit = await openChat(cart);

      await cubit.sendMessage('عايز اطلب لاتيه كبير');
      await cubit.sendMessage('أيوه');

      expect(cart.calls, hasLength(1));
      expect(lastAnswer(cubit).sourceId, 'cart-write-failed');
      expect(lastAnswer(cubit).text, contains('تعذر'));
      expect(lastAnswer(cubit).text, isNot(contains('حطيت')));
    });

    test('a cart layer that throws is reported as a failure', () async {
      final cart = _FakeCart()..error = Exception('cart down');
      final cubit = await openChat(cart);

      await cubit.sendMessage('عايز اطلب لاتيه كبير');
      await cubit.sendMessage('أيوه');

      expect(cart.calls, hasLength(1));
      expect(lastAnswer(cubit).sourceId, 'cart-write-failed');
      expect(lastAnswer(cubit).text, contains('تعذر'));
    });

    test('no cart layer never claims a write happened', () async {
      final cubit = AssistantCubit(
        catalog: const MockProductRepository(),
        orders: _NoOrders(),
        memoryStore: const NoAssistantMemoryStore(),
        retrieval: const NoRetrieval(),
      );
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.sendMessage('عايز اطلب لاتيه كبير');
      await cubit.sendMessage('أيوه');

      // With nowhere to write, the assistant must not say it added anything.
      expect(lastAnswer(cubit).sourceId, 'cart-write-failed');
      expect(lastAnswer(cubit).text, isNot(contains('حطيت')));
    });
  });

  group('a write needs an explicit yes first', () {
    test('a direct add proposes instead of writing', () async {
      final cart = _FakeCart();
      final cubit = await openChat(cart);

      await cubit.sendMessage('ضيف لاتيه للسلة');

      expect(lastAnswer(cubit).sourceId, 'order-confirm');
      expect(cart.calls, isEmpty);

      await cubit.sendMessage('أيوه');
      expect(cart.calls, hasLength(1));
    });

    test('paying an unconfirmed draft asks to confirm, not write', () async {
      final cart = _FakeCart();
      final cubit = await openChat(cart);

      await cubit.sendMessage('عايز اطلب لاتيه كبير');
      await cubit.sendMessage('ادفع دلوقتي');

      // The draft is still waiting for a yes: nothing may slip into the cart
      // on the way to payment, whichever answer the router gives.
      expect(cart.calls, isEmpty);
      expect(lastAnswer(cubit).sourceId, isNot('order-confirmed'));
    });

    test('a stray yes with no proposal writes nothing', () async {
      final cart = _FakeCart();
      final cubit = await openChat(cart);

      await cubit.sendMessage('أيوه');

      expect(cart.calls, isEmpty);
      expect(lastAnswer(cubit).sourceId, isNot('order-confirmed'));
    });
  });
}