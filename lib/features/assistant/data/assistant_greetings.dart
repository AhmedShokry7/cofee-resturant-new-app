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

  /// Friendly per-order status line ("your order is being prepared...").
  static String orderStatusLine(OrderItemModel order) {
    final name = order.product.name;
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
      now.hour < 12 ? 'صباح الفل' : 'مساء الفل';

  static String chatGreetingAr({
    required bool isReturning,
    String? firstName,
    required DateTime now,
  }) {
    final day = _dayPartAr(now);
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? '' : ' يا $name';
    if (isReturning) {
      return '$day$who! وحشتني.';
    }
    // A person does not introduce themselves by listing what they can do.
    // They say hello and let the customer ask.
    return '$day$who! قولي محتاج إيه.';
  }

  /// Arabic per-order status line (طلبك بيتحضر...).
  static String orderStatusLineAr(OrderItemModel order) {
    final name = order.product.name;
    switch (order.status.name) {
      case 'active':
        return 'طلبك $name بيتحضر دلوقتي وهيجهز قريب.';
      case 'completed':
        return 'طلبك $name وصل — بالهنا والشفا!';
      case 'cancelled':
        return 'طلبك $name اتلغى.';
      default:
        return 'حالة طلبك $name: ${order.status.label}.';
    }
  }
}
