// What the assistant hands to the language model.
//
// The model only ever sees what this file builds. A missing fact here is a
// fact the model has to guess: it invented the opening hours ("من الساعتين
// لحد بليل") and a delivery policy until the shop's own knowledge reached it.
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/llm/rag_context.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_reply_sanitizer.dart';

void main() {
  group('the shop knowledge reaches the model', () {
    test('an Arabic question finds the Arabic article', () {
      final context = buildLocalContext(
        'امتى بتقفلوا',
        AssistantMemory(replyArabic: true),
      );

      expect(
        context,
        contains('7:00'),
        reason: 'the opening hours are the answer to this question',
      );
      expect(context, isNot(contains('No local knowledge matched')));
    });

    test('the facts every answer needs are always there', () {
      final context = buildLocalContext(
        'ايه رأيك في الطقس؟',
        AssistantMemory(replyArabic: true),
      );

      // Nothing matched this question, but the model must still know the
      // hours, the delivery and the payment instead of inventing them.
      expect(context, contains('7:00'));
      expect(context, contains('25'));
      expect(context, contains('كاش'));
    });

    test('the knowledge is written in the customer language', () {
      final context = buildLocalContext(
        'امتى بتقفلوا',
        AssistantMemory(replyArabic: false),
      );

      expect(context, contains('بنفتح كل يوم'));
      expect(context, isNot(contains('We are open every day')));
    });
  });

  group('the system prompt', () {
    test('shows the model the tone and the length', () {
      final prompt = buildSystemPrompt(memory: AssistantMemory(replyArabic: true));

      expect(prompt, contains('Egyptian Arabic'));
      expect(prompt, contains('two or three short sentences'));
      expect(prompt, contains('never name another currency'));
      expect(prompt, contains('Name each product once'));
      // The examples are what actually teach the style.
      expect(prompt, contains('سعر اللاتيه 35.00 SAR'));
      expect(prompt, contains('بنفتح كل يوم من 7:00 الصبح'));
    });

    test('forbids the markdown a model writes for documents', () {
      final prompt = buildSystemPrompt(memory: AssistantMemory(replyArabic: true));

      // A single Markdown table in an example is enough to make the model
      // answer every comparison with a table, and a table in a chat bubble is
      // a wall of pipes.
      expect(prompt, contains('Never use markdown'));
      expect(prompt, contains('no tables'));
      expect(prompt, isNot(contains('|')));
    });

    test('the examples are plain chat messages', () {
      final prompt = buildSystemPrompt(memory: AssistantMemory(replyArabic: true));

      expect(prompt, contains('plain chat messages'));
      expect(prompt, isNot(contains('**')));
      expect(prompt, isNot(contains('```')));
    });
  });

  group('the model reply', () {
    test('loses its markdown before it reaches the chat', () {
      expect(sanitizeLlmReply('سعر **35 ريال**'), 'سعر 35 ريال');
    });
  });
}
