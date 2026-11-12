import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

/// The assistant's opening line, used when the customer opens the chat. It
/// speaks only then — never as a bubble on the entry button.
class AssistantGreetings {
  const AssistantGreetings._();

  static String chatGreeting({
    required bool isReturning,
    String? firstName,
    required DateTime now,
  }) {
    final day = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? '' : ' $name';
    if (isReturning) {
      return '$day$who! Good to see you.';
    }
    // A person does not introduce themselves by listing what they can do.
    // They say hello and let the customer ask.
    return '$day$who! What can I get you?';
  }

  /// Answer a short greeting with the same greeting, instead of an unrelated
  /// time-of-day opener (for example, "hi" -> "Hi!").
  static String replyToGreeting({
    required String query,
    required bool arabic,
    required bool isReturning,
    String? firstName,
    required DateTime now,
  }) {
    final normalized = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]+'), ' ')
        .trim();
    if (!arabic && const {'hi', 'hello', 'hey'}.contains(normalized)) {
      final name = (firstName ?? '').trim();
      final who = name.isEmpty ? '' : ' $name';
      final greeting = normalized[0].toUpperCase() + normalized.substring(1);
      return '$greeting$who! What can I get you?';
    }
    if (arabic) {
      final normalizedArabic = normalizeText(query);
      if (normalizedArabic == 'السلام عليكم' ||
          normalizedArabic == 'سلام عليكم') {
        return 'وعليكم السلام! كيف أقدر أخدمك؟';
      }
      if (normalizedArabic == 'مرحبا' ||
          normalizedArabic == 'اهلا' ||
          normalizedArabic == 'هلا') {
        return 'هلا وغلا! أنا حاضر، وش تحتاج؟';
      }
      // Dialect greetings get a dialect answer: a bare hello is met with a
      // warm hello, and a "how are you" is answered before the pitch.
      const helloWords = ['هلا والله', 'هلا', 'هاي', 'هلو', 'ياهلا'];
      for (final word in helloWords) {
        if (normalizedArabic == normalizeText(word)) {
          // Small talk answers without a pitch question: a hello is met
          // with a hello, and the customer asks when they are ready.
          return 'هلا والله! أمرّك بأي وقت.';
        }
      }
      const howAreYou = [
        'شلونك',
        'شحالك',
        'شخبارك',
        'كيفك',
        'كيف حالك',
        'ازيك',
        'عامل ايه',
        'عاملين ايه',
        'اخبارك',
        'شحالك',
        'واخبارك',
      ];
      for (final word in howAreYou) {
        if (normalizedArabic.contains(normalizeText(word))) {
          return 'الحمد لله بخير! أخباري تمام — وأنا تحت أمرك في أي وقت.';
        }
      }
    }
    return arabic
        ? chatGreetingAr(
            isReturning: isReturning,
            firstName: firstName,
            now: now,
          )
        : chatGreeting(
            isReturning: isReturning,
            firstName: firstName,
            now: now,
          );
  }

  /// Friendly per-order status line ("your order is being prepared...").
  static String orderStatusLine(OrderItemModel order) {
    final name = AssistantSnapshot.canonicalName(order.product);
    switch (order.status.name) {
      case 'active':
        return 'Your $name is being prepared and will be ready soon.';
      case 'completed':
        return 'Your $name was delivered — enjoy! بالهنا والشفا.';
      case 'cancelled':
        return 'Your $name order was cancelled.';
      default:
        return 'Your $name order status: ${order.status.label}.';
    }
  }

  // ==================== Egyptian Arabic ====================

  static String _dayPartAr(DateTime now) =>
      now.hour < 12 ? 'صباح الخير' : 'مساء الخير';

  static String chatGreetingAr({
    required bool isReturning,
    String? firstName,
    required DateTime now,
  }) {
    final day = _dayPartAr(now);
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? '' : ' يا $name';
    if (isReturning) {
      return '$day$who! اشتقنا لك.';
    }
    // A person does not introduce themselves by listing what they can do.
    // They say hello and let the customer ask.
    return '$day$who! كيف أقدر أخدمك؟';
  }

  /// Arabic per-order status line (طلبك بيتحضر...).
  static String orderStatusLineAr(OrderItemModel order) {
    final name = AssistantSnapshot.canonicalName(order.product);
    switch (order.status.name) {
      case 'active':
        return 'طلبك $name بيجهز الحين وبيكون جاهز قريب.';
      case 'completed':
        return 'طلبك $name وصل — بالهنا والشفاء!';
      case 'cancelled':
        return 'طلبك $name اتلغت.';
      default:
        return 'حالة طلبك $name: ${order.status.label}.';
    }
  }
}
