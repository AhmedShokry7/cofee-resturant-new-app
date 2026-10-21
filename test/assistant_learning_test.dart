// The assistant's contract with the language model.
//
// Two things matter here: the question is sent in the form the memory is keyed
// by, and a question whose answer goes stale is never learned.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_reply_sanitizer.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

/// Records what the cubit asked the model.
class _RecordingLlmClient implements LlmClient {
  final List<({String questionKey, bool learn, String query})> calls = [];

  @override
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
    String questionKey = '',
    bool learn = true,
  }) async {
    calls.add((questionKey: questionKey, learn: learn, query: query));
    return const LlmReply(text: 'رد الموديل', provider: 'groq');
  }
}

class _NoOrders implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => const [];

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) async {}

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) async => throw UnimplementedError();

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  Future<({AssistantCubit cubit, _RecordingLlmClient llm})> open() async {
    final llm = _RecordingLlmClient();
    final cubit = AssistantCubit(
      catalog: const MockProductRepository(),
      orders: _NoOrders(),
      llmClient: llm,
    );
    addTearDown(cubit.close);
    await cubit.start();
    return (cubit: cubit, llm: llm);
  }

  test('the question is sent in the form the memory is keyed by', () async {
    final opened = await open();

    await opened.cubit.sendMessage('ايه رأيك في طقس اليوم؟');
    // The model is only asked when the local engine cannot answer.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(opened.llm.calls, isNotEmpty);
    final call = opened.llm.calls.last;
    expect(call.query, 'ايه رأيك في طقس اليوم؟');
    expect(
      call.questionKey,
      'ايه رايك في طقس يوم',
      reason: 'the key is the normalized question, the way the memory stores it',
    );
    expect(call.questionKey, isNot(contains('?')));
    expect(call.questionKey, isNot(contains('ال')));
  });

  test('a question the customer already answered locally never reaches the model',
      () async {
    final opened = await open();

    await opened.cubit.sendMessage('كام سعر اللاتيه؟');
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(
      opened.llm.calls,
      isEmpty,
      reason: 'the local engine answered, so the model is not asked',
    );
  });

  test('an answer about the customer own order is never learned', () async {
    expect(
      AssistantEngine.isPerishableQuestion('فين طلبي؟'),
      isTrue,
      reason: 'the answer is true for that customer and false for the next one',
    );
    expect(AssistantEngine.isPerishableQuestion('كام سعر اللاتيه؟'), isTrue);
    expect(
      AssistantEngine.isPerishableQuestion('ايه رأيك في طقس اليوم؟'),
      isFalse,
      reason: 'a general question is worth remembering',
    );
  });

  test('the reply says where it came from', () {
    expect(
      const LlmReply(text: 'x', provider: 'memory').fromMemory,
      isTrue,
    );
    expect(
      const LlmReply(text: 'x', provider: 'groq').fromMemory,
      isFalse,
    );
  });

  test('the model reply loses its markdown', () {
    expect(
      sanitizeLlmReply('السعر **35 ريال**'),
      'السعر 35 ريال',
    );
  });
}
