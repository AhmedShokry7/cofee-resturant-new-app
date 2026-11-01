// The assistant keeps the thread of the conversation.
//
// A follow-up rarely names its subject: "كام سعره؟" ("how much is it?") after
// a suggestion means the thing that was just suggested. These tests pin the
// context rules that make the bot answer about the same product instead of
// about something else entirely.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'support/mock_product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  late AssistantSnapshot snapshot;

  setUpAll(() async {
    await AssistantCatalog.load();
    snapshot = await AssistantSnapshot.load(
      catalog: const MockProductRepository(),
      activeOrders: () async => const <OrderItemModel>[],
    );
  });

  /// Runs a conversation the way the cubit does: the query and the topic are
  /// recorded, and the next turn reads them back as context.
  List<({String query, String topic, String text})> converse(
    List<String> turns,
  ) {
    final memory = AssistantMemory(replyArabic: true);
    final log = <({String query, String topic, String text})>[];
    for (final turn in turns) {
      memory.recordQuery(turn);
      final answer = AssistantEngine.answer(
        turn,
        snapshot: snapshot,
        memory: memory,
        now: DateTime.now(),
      );
      memory.recordTopic(answer.topic);
      log.add((query: turn, topic: answer.topic, text: answer.text));
    }
    return log;
  }

  group('following up on a suggestion', () {
    test('the price question is about the product on screen', () {
      final log = converse(['عايز اشرب ايه', 'كام سعره؟']);

      expect(log.first.topic, 'suggest');
      expect(log.last.topic, 'prices', reason: 'a price question stays a price question');
      expect(
        log.last.text,
        isNot(contains('عروض')),
        reason: 'the customer asked for a price, not for coupons',
      );
    });

    test('a pronoun points at the product on screen', () {
      final log = converse(['رشحلي حاجة حلوة', 'ده بكام؟']);

      expect(log.last.topic, 'prices');
      expect(log.last.text, contains('ر.س'));
    });

    test('"is that what you suggested" confirms instead of re-suggesting', () {
      final log = converse(['رشحلي حاجة حلوة', 'هو ده اللي رشحته؟']);

      expect(log.last.topic, 'suggest');
      expect(log.last.text, contains('أيوه'));
    });

    test('a bare follow-up keeps talking about the menu', () {
      final log = converse(['عايز اشرب ايه', 'وكمان هو؟']);

      expect(
        log.last.topic,
        isNot('fallback'),
        reason: 'the bot must not give up on a question about its own menu',
      );
    });
  });

  group('following up on a product', () {
    test('the options question is about the product on screen', () {
      final log = converse(['عايز اعرف عن اللاتيه', 'فيه سكر اقل؟']);

      expect(log.last.topic, 'options');
      expect(log.last.text, contains('سكر'));
      expect(
        log.last.text,
        contains('Latte'),
        reason: 'the answer is about the product that was just shown',
      );
    });

    test('the price after an options question is still that product', () {
      final log = converse(['عايز اعرف عن اللاتيه', 'فيه سكر اقل؟', 'وكم سعره؟']);

      expect(log.last.topic, 'prices');
      expect(log.last.text, contains('Latte'));
    });
  });

  group('orders', () {
    test('"I ordered yesterday" is about the past order, not a new one', () {
      final log = converse(['اطلبت امبارح']);

      expect(
        log.last.topic,
        'orders',
        reason: 'a past order must not start a fresh one',
      );
    });

    test('an order in progress is confirmed and then paid for', () {
      final log = converse(['عايز اطلب لاتيه كبير', 'ايوه', 'ادفع دلوقتي']);

      expect(log[0].topic, 'order');
      expect(log[0].text, contains('أكد'), reason: 'the order asks to be confirmed');
      expect(log[1].text, contains('السلة'), reason: 'the yes fills the cart');
      expect(log[2].topic, 'order');
    });
  });
}
