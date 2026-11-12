import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';

void main() {
  test('example-bank matching catches paraphrases and typos', () {
    final cases = <String, AssistantIntent>{
      // Paraphrases with no intent keyword at all.
      'انا زهقان وابغى حاجة تشرب الحين': AssistantIntent.suggestDrink,
      'دلوقتي نفسي في حاجة مثلجة ومسكرة': AssistantIntent.suggestDrink,
      'فين الطلبية اللي طلبتها امبارح': AssistantIntent.orderStatus,
      'عندكم كود خصم استخدمه على الفاتورة': AssistantIntent.showCoupons,
      'هسلم كاش للمندوب لما يوصل': AssistantIntent.payCash,
      'القهوة اللي فاتت طعمها وحش جدا': AssistantIntent.complaint,
      // Typo-ridden sentences still land.
      'فين طلبى اللى عملتو امبارح': AssistantIntent.orderStatus,
      'عايز حاجه حلوووہ وساقعه': AssistantIntent.suggestDrink,
      'ضيف ده على السلة بالظبط': AssistantIntent.addToCart,
    };
    cases.forEach((query, expected) {
      final got = detectIntent(query);
      expect(got, expected, reason: '"$query" -> $got');
    });
  });
}
