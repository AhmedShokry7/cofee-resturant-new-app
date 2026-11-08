// The assistant's multi-turn order, tested on its own.
//
// These are the only assistant answers that change state: the draft grows,
// the pending question moves, the cart actions are produced. The routing that
// decides *when* to call them is covered by the engine tests; this file covers
// what the flow itself promises the customer.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_draft_flow.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_order.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

import 'support/mock_product_repository.dart';

late AssistantSnapshot _snapshot;

/// Runs [body] the way the engine runs it, with the catalogue in scope.
T _withCatalog<T>(T Function() body) => AssistantSnapshot.run(_snapshot, body);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  setUpAll(() async {
    await AssistantCatalog.load();
    _snapshot = await AssistantSnapshot.load(
      catalog: const MockProductRepository(),
      activeOrders: () async => const <OrderItemModel>[],
    );
  });

  group('AssistantDraftFlow', () {
    test('an order line is drafted and the customer is asked to confirm', () {
      final memory = AssistantMemory();

      final answer = _withCatalog(
        () => AssistantDraftFlow.takeOrder(
          'عايز اطلب لاتيه كبير',
          memory: memory,
          now: DateTime(2026, 11, 1),
          arabic: true,
        ),
      );

      expect(answer.sourceId, 'order-confirm');
      expect(memory.pendingQuestion, 'order_confirm');
      expect(memory.draft.items, hasLength(1));
      expect(answer.products, isNotEmpty);
      expect(answer.text, contains('أكد'));
    });

    test('an order naming no product asks what the customer wants', () {
      final memory = AssistantMemory();

      final answer = _withCatalog(
        () => AssistantDraftFlow.takeOrder(
          'عايز اطلب حاجة',
          memory: memory,
          now: DateTime(2026, 11, 1),
          arabic: true,
        ),
      );

      expect(answer.sourceId, 'order-empty');
      expect(memory.draft.items, isEmpty);
    });

    test('an unspecified dessert defers the size and offers choices', () {
      final memory = AssistantMemory();

      final answer = _withCatalog(
        () => AssistantDraftFlow.takeOrder(
          'عايز لاتيه كبير وطبق حلو',
          memory: memory,
          now: DateTime(2026, 11, 1),
          arabic: true,
        ),
      );

      expect(answer.sourceId, 'order-clarify');
      expect(memory.pendingQuestion, 'order_clarify');
      // The chips are gone, so the sentence itself has to name every choice
      // the customer can reply with.
      final options = _withCatalog(AssistantDraftFlow.dessertOptions);
      expect(options, isNotEmpty);
      for (final product in options) {
        expect(answer.text, contains(product.name));
      }
    });

    test('the clarification reuses the size held from the first message', () {
      final memory = AssistantMemory();

      _withCatalog(
        () => AssistantDraftFlow.takeOrder(
          'عايز لاتيه كبير وحلوة',
          memory: memory,
          now: DateTime(2026, 11, 1),
          arabic: true,
        ),
      );
      final pendingSize = memory.pendingDessertSize;
      final answer = _withCatalog(
        () => AssistantDraftFlow.resolveClarify(
          'تشيز كيك',
          memory: memory,
          arabic: true,
        ),
      );

      expect(answer?.sourceId, 'order-confirm');
      expect(memory.pendingDessertSize, isNull);
      expect(
        memory.draft.items.map((item) => item.size),
        contains(pendingSize),
      );
    });

    test('confirming fills the cart actions and empties the draft', () {
      final memory = AssistantMemory()
        ..draft.add(_item('3', quantity: 2, size: 'large'));

      final answer = _withCatalog(
        () => AssistantDraftFlow.executeConfirm(memory, arabic: true),
      );

      expect(answer.sourceId, 'order-confirmed');
      expect(answer.actions, hasLength(1));
      expect(answer.actions.single.quantity, 2);
      expect(answer.actions.single.approvedBy, 'explicit_confirm');
      expect(memory.draft.items, isEmpty);
      expect(memory.pendingQuestion, 'order_payment');
    });

    test('confirming an empty draft says so instead of adding nothing', () {
      final memory = AssistantMemory();

      final answer = _withCatalog(
        () => AssistantDraftFlow.executeConfirm(memory, arabic: true),
      );

      expect(answer.sourceId, 'order-empty-confirm');
      expect(answer.actions, isEmpty);
      expect(memory.pendingQuestion, isNull);
    });

    test('the total question reads the draft without clearing it', () {
      final memory = AssistantMemory()..draft.add(_item('3'));

      final answer = _withCatalog(
        () => AssistantDraftFlow.draftTotal(memory, arabic: true),
      );

      expect(answer.sourceId, 'order-total');
      expect(memory.draft.items, hasLength(1));
    });

    test('cancelling an order that was never started says so', () {
      final memory = AssistantMemory();

      final answer = _withCatalog(
        () => AssistantDraftFlow.cancelDraft(memory, arabic: true),
      );

      expect(answer.sourceId, 'order-cancel-empty');
    });

    test('paying an unconfirmed draft asks to confirm first, not write', () {
      final memory = AssistantMemory()
        ..pendingQuestion = 'order_payment'
        ..draft.add(_item('3'));

      final answer = _withCatalog(
        () => AssistantDraftFlow.payChoice(memory, arabic: true, now: true),
      );

      // The draft is a write waiting for a yes: paying must not push it into
      // the cart silently on the way to checkout.
      expect(answer.sourceId, 'order-confirm');
      expect(answer.destination, isNull);
      expect(answer.actions, isEmpty);
      expect(memory.draft.items, hasLength(1));
      expect(memory.pendingQuestion, 'order_confirm');
    });

    test('paying with nothing drafted opens checkout without writing', () {
      final memory = AssistantMemory()..pendingQuestion = 'order_payment';

      final answer = _withCatalog(
        () => AssistantDraftFlow.payChoice(memory, arabic: true, now: true),
      );

      expect(answer.destination, AssistantDestination.checkout);
      expect(answer.actions, isEmpty);
      expect(memory.pendingQuestion, isNull);
    });

    test('a direct add proposes and waits for confirmation', () {
      final memory = AssistantMemory();

      final answer = _withCatalog(
        () => AssistantDraftFlow.addDirect(
          'ضيف لاتيه للسلة',
          memory: memory,
          arabic: true,
        ),
      );

      // Adding to the cart is a write: it proposes first instead of pushing
      // the product in on the wording alone.
      expect(answer.sourceId, 'order-confirm');
      expect(answer.actions, isEmpty);
      expect(answer.text, contains('أكد'));
      expect(memory.draft.items, hasLength(1));
      expect(memory.pendingQuestion, 'order_confirm');
    });

    test('a refusal after a suggestion asks for a direction', () {
      final memory = AssistantMemory()..lastTopic = 'suggest';

      final answer = _withCatalog(
        () => AssistantDraftFlow.deny(memory, arabic: true),
      );

      expect(answer.topic, 'deny');
      // No chips to point at: the answer has to say how to steer it.
      expect(answer.text, contains('قوي'));
    });
  });
}

OrderDraftItem _item(String productId, {int quantity = 1, String? size}) =>
    OrderDraftItem(productId: productId, quantity: quantity, size: size);
