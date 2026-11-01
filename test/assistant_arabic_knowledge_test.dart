// The shop's facts, in the customer's language.
//
// The knowledge base used to be English only, so an Arabic question about the
// hours, the delivery or the payment could not find its article and the
// language model had to answer instead. These tests pin the Arabic side.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/knowledge/coffee_knowledge.dart';
import 'package:new_coffee/features/assistant/data/knowledge/faq_knowledge.dart';
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

  AssistantAnswer ask(String query) => AssistantEngine.answer(
    query,
    snapshot: snapshot,
    memory: AssistantMemory(replyArabic: true),
    now: DateTime.now(),
  );

  group('Arabic shop facts', () {
    test('the hours are answered from the shop, in Arabic', () {
      final answer = ask('امتى بتقفلوا؟');

      expect(answer.sourceId, 'faq-hours');
      expect(answer.text, contains('7:00'));
      expect(
        answer.text,
        isNot(contains('We are open')),
        reason: 'an Arabic customer must not read the English article',
      );
    });

    test('the delivery question is not mistaken for an order status', () {
      final answer = ask('بتعملوا توصيل؟');

      expect(answer.sourceId, 'faq-delivery');
      expect(answer.text, contains('25'));
    });

    test('the payment question is not mistaken for a greeting', () {
      final answer = ask('كيف بدفع؟');

      expect(answer.sourceId, 'faq-payment');
      expect(answer.text, contains('كاش'));
    });

    test('the tracking question points at the orders page', () {
      final answer = ask('ازاي اتابع طلبي؟');

      expect(answer.sourceId, 'faq-track');
      expect(answer.text, contains('طلباتي'));
    });

    test('a late order is a refund answer, not a suggestion', () {
      final answer = ask('الطلب اتأخر');

      expect(answer.sourceId, 'faq-refund');
    });

    test('the contact question reaches a person', () {
      final answer = ask('بتكلم حد؟');

      expect(answer.sourceId, 'faq-contact');
    });

    test('the favourites question explains the heart', () {
      final answer = ask('ازاي احفظ المفضلة؟');

      expect(answer.sourceId, 'faq-favorites');
    });
  });

  group('Arabic drink knowledge', () {
    test('a drink question is answered from the menu knowledge', () {
      final answer = ask('كام كافيين في Shot واحد؟');

      expect(answer.sourceId, 'caffeine-guide');
      expect(answer.text, contains('كافيين'));
    });

    test('what to eat with the coffee is answered from the knowledge', () {
      final answer = ask('ايه احسن حاجة مع القهوة؟');

      expect(answer.sourceId, 'snacks-pairing');
    });
  });

  group('an ingredient the shop does not carry', () {
    test('is refused honestly, in Arabic', () {
      final answer = ask('عايز حاجه بالمكسرات');

      expect(answer.sourceId, 'ingredient-none');
      expect(
        answer.text,
        contains('مكسرات'),
        reason: 'the ingredient is named in the customer language',
      );
      expect(answer.text, isNot(contains('nuts')));
    });

    test('an ingredient the shop does carry still matches', () {
      final answer = ask('عايز حاجه بالشوكولاتة');

      expect(answer.sourceId, isNot('ingredient-none'));
    });
  });

  group('the knowledge base itself', () {
    test('every article has an Arabic body and Arabic keywords', () {
      final articles = [...faqKnowledge, ...coffeeKnowledge];
      for (final article in articles) {
        expect(
          article.bodyAr,
          isNotNull,
          reason: '${article.id} has no Arabic body',
        );
        expect(
          article.keywordsAr,
          isNotEmpty,
          reason: '${article.id} cannot be found by an Arabic question',
        );
        expect(
          article.bodyFor(arabic: true),
          isNot(article.body),
          reason: '${article.id} answers in English for an Arabic customer',
        );
      }
    });

    test('the Arabic bodies have no English left in them', () {
      final articles = [...faqKnowledge, ...coffeeKnowledge];
      for (final article in articles) {
        final body = article.bodyAr ?? '';
        // A stray Latin word reads as broken to a customer. Product and menu
        // names are allowed; ordinary English words are not.
        final latinWords = RegExp(
          r'[A-Za-z]{3,}',
        ).allMatches(body).map((m) => m.group(0)!).toSet();
        final allowed = {
          'Cappuccino',
          'Latte',
          'Iced',
          'Mocha',
          'Cheesecake',
          'Chocolate',
          'Milkshake',
          'Green',
          'Tea',
          'Masala',
          'Espresso',
          'Americano',
          'Apple',
          'Pay',
          'Google',
          'Shot',
          'French',
          'press',
        };
        for (final word in latinWords) {
          expect(
            allowed.contains(word),
            isTrue,
            reason: '${article.id} has the English word "$word" in its Arabic body',
          );
        }
      }
    });
  });
}
