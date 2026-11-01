// How much of what a customer types is answered on the device.
//
// The language model is a fallback for what the local engine cannot answer.
// It costs a round trip, it is slow, and it does not know the shop. So the
// measure that matters is: how much reaches it.
//
// This list is deliberately wide and deliberately ordinary. A question that
// lands on the `fallback` topic is one the language model has to take.
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

  /// Everyday Arabic a customer actually types.
  const everyday = <String>[
    // Ordering
    'عايز اطلب لاتيه كبير',
    'محتاج 3 اسبريسو',
    'هاتلي كابتشينو',
    'ممكن اربع اسبريسو؟',
    'عايز موكا بارد',
    'عايزك تحطلي لاتيه في السلة',
    'ضيف كابتشينو للسلة',
    'الغي الطلب',
    'كنسل الاوردر',
    // Sizes, sugar, extras
    'عايزه كبيره',
    'من غير سكر',
    'سكر قليل من فضلك',
    'مع كرميله',
    'عايزه وسط',
    // Prices
    'بكام اللاتيه',
    'كام سعر الموكا',
    'الاسعار كام',
    'كام سعر التشيز كيك',
    'المجموع كام',
    // The menu
    'عندكم تشيز كيك؟',
    'عندكم حاجه بالمكسرات؟',
    'ايه الحلويات اللي عندكم',
    'القائمه فيها ايه',
    'منيو',
    'عندكم قهوه بلبن؟',
    'عندكم شاي؟',
    // The order
    'فين طلبي',
    'طلبي وصل؟',
    'الطلب اتعمل؟',
    'عايز الغي الاوردر',
    'كم استغرق الطلب',
    // Coupons
    'في كود خصم',
    'عندكم عروض؟',
    'الخصم كام',
    // Usual
    'نفس الطلب بتاعي',
    'زي كل مره',
    'اللي بحبه دايما',
    'المعتاد',
    // Small talk
    'ازيك',
    'عامل ايه',
    'انت مين',
    'شكرا',
    'مع السلامه',
    'سلام عليكم',
    'مساء الخير',
    'السلامه عليكم',
    // Refusals
    'مش عايز',
    'بلاش',
    'لا شكرا',
    'مش حلو',
    'غالي',
    'طعمها وحش',
    // Clarification
    'يعني ايه؟',
    'ممكن توضحلي',
    'ايه الخيارات',
    'فيه انواع تانية؟',
    // The shop's facts
    'امتى بتقفلوا',
    'بتعملوا توصيل',
    'كيف بدفع',
    'ازاي اتابع طلبي',
    'نسيت كلمه المرور',
    'بتكلم حد',
    'ازاي احفظ المفضله',
    'كام كافيين في Shot واحد',
    'ايه احسن حاجه مع القهوه',
    // Mixed / Arabizi
    '3ayez espresso',
    'kafe',
    // Longer, real sentences
    'انا عايز اشرب حاجة حلوة سريعة',
    'لو فيه عرض على القهوة اليوم قولي',
    'ابغى اعرف ايش الفرق بين اللاتيه والكابتشينو',
    'كم السعر لو زدت شوكولا',
    'فين اطلب من هنا',
    'شكرا جزيلا',
    'ماشي يلا',
    'تمام كده',
    'يلا نطلب',
    'عايز اعرف مواعيد العمل',
    'بتعملوا توصيل ولا لأ',
  ];

  test('almost every everyday question is answered on the device', () {
    final handedToTheModel = <String>[];
    for (final query in everyday) {
      final memory = AssistantMemory(replyArabic: true);
      final answer = AssistantEngine.answer(
        query,
        snapshot: snapshot,
        memory: memory,
        now: DateTime.now(),
      );
      if (answer.topic == 'fallback' || answer.topic == 'unknown') {
        handedToTheModel.add(query);
      }
    }

    expect(
      handedToTheModel,
      isEmpty,
      reason: 'these questions must not need the language model',
    );
  });

  test('the shop facts are answered from the shop', () {
    final memory = AssistantMemory(replyArabic: true);
    final answer = AssistantEngine.answer(
      'امتى بتقفلوا',
      snapshot: snapshot,
      memory: memory,
      now: DateTime.now(),
    );

    expect(answer.sourceId, 'faq-hours');
    expect(answer.topic, isNot('fallback'));
  });
}
