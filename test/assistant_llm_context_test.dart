// What the assistant hands to the language model.
//
// The model only ever sees what this file builds, so a missing fact here is a
// fact the model has to guess. It guessed the currency once: "35 dinars" and
// "40 IQD" for a shop that charges riyals.
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/llm/rag_context.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

void main() {
  final snapshot = AssistantSnapshot(
    products: const [
      ProductModel(
        id: 'p1',
        name: 'Latte',
        nameEn: 'Latte',
        category: 'Hot Coffee',
        price: 35,
        image: '',
      ),
    ],
    orders: const <OrderItemModel>[],
  );

  test('the live context names the currency the shop charges in', () {
    final context = buildLiveContext(
      AssistantMemory(replyArabic: true),
      snapshot: snapshot,
    );

    expect(context, contains('SAR'));
    expect(
      context,
      contains('price in SAR'),
      reason: 'the menu header must say what the numbers are',
    );
    expect(
      context,
      contains('Latin digits'),
      reason: 'the model writes Arabic-Indic digits unless it is told not to',
    );
    expect(context, contains('Never name another currency'));
  });

  test('the system prompt keeps the model on the shop currency', () {
    final prompt = buildSystemPrompt(
      memory: AssistantMemory(replyArabic: true),
    );

    expect(prompt, contains('SAR'));
    expect(prompt, contains('Latin digits'));
    expect(prompt, contains('never invent products, prices'));
  });

  test('no example answer ends by pitching something', () {
    // The examples teach the shape of an answer better than the rules do, so a
    // single "تحب أضيفه لك؟" in one of them reappears in every reply.
    final prompt = buildSystemPrompt(
      memory: AssistantMemory(replyArabic: true),
    );
    final examples = prompt
        .split('Examples of the right answer')
        .last
        .split('\n')
        .where((line) => line.startsWith('Assistant: '))
        .toList();

    expect(examples, isNotEmpty);
    for (final line in examples) {
      expect(line, isNot(contains('؟')));
      expect(line, isNot(contains('?')));
    }
  });

  test('the menu is grounded with the real names and prices', () {
    final context = buildLiveContext(
      AssistantMemory(replyArabic: true),
      snapshot: snapshot,
    );

    expect(context, contains('Latte'));
    expect(context, contains('35'));
  });
}
