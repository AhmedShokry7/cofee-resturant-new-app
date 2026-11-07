// Who is allowed to answer one customer sentence.
//
// The offline engine answers by scoring keywords against an intent table, and
// it always found *some* intent, so it always answered with confidence. On
// thirty real customer sentences that meant twenty-eight were answered locally
// and two reached the language model — which is how "عايز اشترك في الاشتراك
// الشهري" and "ايه احسن حاجة للاولاد الصغار؟" both came back as the default
// three-drink list. [AssistantUnderstanding] owns the one question the engine
// cannot answer about itself: does the app actually hold the data the sentence
// asks about? These tests pin the measured decisions so a rule change has to
// move a sentence on purpose, not by accident.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/assistant_understanding.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

import 'support/mock_product_repository.dart';

void main() {
  late AssistantSnapshot snapshot;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await AssistantCatalog.load();
    snapshot = await AssistantSnapshot.load(
      catalog: const MockProductRepository(),
      activeOrders: () async => const <OrderItemModel>[],
    );
  });

  /// A fresh memory per sentence: a fact learned while reading one question
  /// would otherwise answer the next one.
  AssistantUnderstanding read(String query) => AssistantUnderstanding.analyse(
    query,
    snapshot: snapshot,
    memory: AssistantMemory(replyArabic: true),
    arabic: true,
  );

  group('the customer own data', () {
    test('a question about an order is answered by the app, not the model', () {
      final reading = read('الطلب اللي عملته امبارح وصل ولا لاء');
      expect(reading.subject, SentenceSubject.ownOrder);
      expect(reading.owner, AnswerOwner.liveData);
      // The keyword scorer tied the order status against a drink suggestion,
      // and the customer was handed three drinks. The reading picks the
      // template the subject really needs.
      expect(reading.deviceIntent, AssistantIntent.orderStatus);
    });

    test('the cart is answered by the app', () {
      final reading = read('غيرت رايي امسح اللي في السلة');
      expect(reading.subject, SentenceSubject.cart);
      expect(reading.owner, AnswerOwner.liveData);
    });

    test('an allergy question is answered by the shop recipe, never guessed', () {
      final reading = read('اللاتيه فيه مكسرات؟ عندي حساسية');
      expect(reading.subject, SentenceSubject.ingredient);
      expect(reading.owner, AnswerOwner.liveData);
      // Treating "does the latte have nuts" as an order would put the allergen
      // in the basket.
      expect(reading.deviceIntent, isNull);
    });

    test('a drink named with its options becomes an order', () {
      // namesAnOrder reads the live menu, so it is checked through a reading.
      expect(
        read('عايز لاتيه من غير سكر').deviceIntent,
        AssistantIntent.placeOrder,
      );
    });
  });

  group('the shop written facts', () {
    const facts = <String>[
      'انتم بتقفلوا امتى؟',
      'ايزي الدفع عند الاستلام؟',
      'نقطة التوصيل توصل حي النرجس؟',
      'عندكم حليب شوفان؟',
    ];

    test('the hours, payment, delivery and milk are the shop facts', () {
      for (final question in facts) {
        expect(
          read(question).owner,
          AnswerOwner.shopKnowledge,
          reason: '$question is answered from an article the shop wrote',
        );
      }
    });
  });

  group('everyday menu asks', () {
    // The set assistant_local_first_test requires the device to answer. A leak
    // here is a menu question sent to a model that cannot show products to tap.
    const everyday = <String>[
      'اقترح عليا حاجة',
      'ممكن اجرب حاجة جديده',
      'شو فيه اليوم',
      'عندكم حلا؟',
      'عايز حلو',
      'ابي مشروب بارد',
      'كمان فيه عروض؟',
      'عايز اعرف احسن قهوه',
      'الناس بتاخد ايه',
      'وش اللى بيعجب الناس',
    ];

    test('none of them is handed to the language model', () {
      final leaked = everyday.where((q) => read(q).wantsLanguageModel).toList();
      expect(
        leaked,
        isEmpty,
        reason: 'only the app can search its own menu and show the drinks',
      );
    });
  });

  group('questions the app cannot ground', () {
    const ungrounded = <String, String>{
      'عايز اشترك في الاشتراك الشهري':
          'the assistant holds no subscription record',
      'عايز اعرف نقاطي عندي كام': 'it holds no loyalty balance either',
      'انا مش لاقي زر الطلب': 'a complaint about the screen, not the menu',
      'اقفل البوت': 'the app has no such control to reach',
      'مسحت المحادثة بالغلط': 'a recovery the assistant was never given',
      'قهوة بدون كافيين': 'a limit about the body, not the menu',
      'ايه احسن حاجة للاولاد الصغار؟': 'a child is not a taste the menu sorts by',
    };

    test('they reach the language model', () {
      for (final entry in ungrounded.entries) {
        expect(
          read(entry.key).wantsLanguageModel,
          isTrue,
          reason: '${entry.key}: ${entry.value}',
        );
      }
    });

    test('a price complaint is answered by the app', () {
      expect(read('السعر غالي شوية').owner, AnswerOwner.liveData);
    });

    test('a rule question about the order is not a menu search', () {
      expect(
        read('مقدر اغير عنوان الطلب بعد ما اطلب؟').wantsLanguageModel,
        isTrue,
        reason: 'it asks about the rules, and the menu cannot answer',
      );
    });
  });

  group('what may be learned', () {
    test('an answer about this customer own order is never shared', () {
      expect(read('فين طلبي؟').safeToLearn, isFalse);
    });

    test('a shop fact is safe to keep for the next customer', () {
      expect(read('انتم بتقفلوا امتى؟').safeToLearn, isTrue);
    });
  });

  group('the scorer reads the sentence', () {
    test('a greeting for help is a greeting', () {
      // "ساعد" (help) lives inside "المساعدة" (the help), and that substring
      // used to outscore the exact "شكرا" — so the sentence read as a hello.
      expect(read('شكرا على المساعدة').intent, AssistantIntent.thanks);
    });
  });

  group('the device answers what the reading says', () {
    AssistantAnswer answerFor(String query) {
      final reading = read(query);
      return AssistantEngine.answer(
        query,
        snapshot: snapshot,
        memory: AssistantMemory(replyArabic: true),
        now: DateTime.now(),
        deviceIntent: reading.deviceIntent,
      );
    }

    test('an order question answers with orders, not drinks', () {
      final answer = answerFor('الطلب اللي عملته امبارح وصل ولا لاء');
      expect(answer.topic, 'orders');
      expect(answer.products, isEmpty);
    });

    test('a drink with its options drafts the order', () {
      final answer = answerFor('عايز لاتيه من غير سكر');
      expect(answer.topic, 'order');
    });
  });
}
