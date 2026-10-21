import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

/// Smart assistant greetings: first-time visitors get a warm welcome,
/// returning customers get a "welcome back" with their name when known.
/// Active orders are mentioned proactively (preparing / ready).
class AssistantGreetings {
  const AssistantGreetings._();

  static String welcomeBubble({
    required bool isReturning,
    String? firstName,
    required DateTime now,
    List<OrderItemModel> activeOrders = const [],
  }) {
    final day = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? '' : ' $name';
    final base = isReturning
        ? '$day$who! Welcome back — good to see you again.'
        : '$day$who! Welcome — I am your coffee assistant.';
    if (activeOrders.isEmpty) return base;
    final first = activeOrders.first.product.name;
    final more = activeOrders.length > 1
        ? ' (+${activeOrders.length - 1} more)'
        : '';
    return '$base Your $first$more is being prepared right now.';
  }

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
      return '$day$who! Good to see you. Your usual, or something new today?';
    }
    // A person does not introduce themselves by listing what they can do.
    // They ask what the customer is in the mood for.
    return '$day$who! Tell me what you are in the mood for and I will pick '
        'something, or bring your usual if you have ordered before.';
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
        return 'Your $name order was cancelled. Want me to suggest something else?';
      default:
        return 'Your $name order status: ${order.status.label}.';
    }
  }

  // ==================== Egyptian Arabic ====================

  static String _dayPartAr(DateTime now) =>
      now.hour < 12 ? 'صباح الفل' : 'مساء الفل';

  static String welcomeBubbleAr({
    required bool isReturning,
    String? firstName,
    required DateTime now,
    List<OrderItemModel> activeOrders = const [],
  }) {
    final day = _dayPartAr(now);
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? '' : ' يا $name';
    final base = isReturning
        ? '$day$who! وحشتني — مبسوط إنك رجعت.'
        : '$day$who! أهلاً بيك — أنا مساعد القهوة بتاعك.';
    if (activeOrders.isEmpty) return base;
    final first = activeOrders.first.product.name;
    final more = activeOrders.length > 1
        ? ' (+${activeOrders.length - 1} كمان)'
        : '';
    return '$base طلبك $first$more بيتحضر دلوقتي.';
  }

  static String chatGreetingAr({
    required bool isReturning,
    String? firstName,
    required DateTime now,
  }) {
    final day = _dayPartAr(now);
    final name = (firstName ?? '').trim();
    final who = name.isEmpty ? '' : ' يا $name';
    if (isReturning) {
      return '$day$who! وحشتني. نطلب المعتاد بتاعك ولا تجرب حاجة جديدة؟';
    }
    // A person does not introduce themselves by listing what they can do.
    // They ask what the customer is in the mood for.
    return '$day$who! قولي إيه اللي على مزاجك وأنا أرشحلك، '
        'أو لو طلبت قبل كده أقدر أجيبلك المعتاد.';
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
        return 'طلبك $name اتلغى. تحب أرشحلك حاجة تانية؟';
      default:
        return 'حالة طلبك $name: ${order.status.label}.';
    }
  }
}
