// The assistant's long-term memory and its retrieval, both behind the
// consent switch.
//
// What these tests guard is the privacy contract, not the wording of an
// answer: nothing is written for a customer who never agreed, a preference
// they stated is written once they did, and taking the agreement back deletes
// the island rather than muting it.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversation_log.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant_memory/assistant_memory_cubit.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

import 'support/mock_product_repository.dart';

/// No order history: these tests are about what is remembered, not about the
/// catalogue the answer is built from.
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

/// Records every call the assistant makes against the customer's island.
class _FakeStore implements AssistantMemoryStore {
  _FakeStore({
    this.memoryEnabled = false,
    this.webSearchEnabled = false,
    List<AssistantMemoryItem>? items,
  }) : items = items ?? [];

  bool memoryEnabled;
  bool webSearchEnabled;
  final List<({String role, String text})> logged = [];
  final List<({AssistantMemoryKind kind, String key, bool isSecret})>
  remembered = [];
  final List<int> ratings = [];
  List<AssistantMemoryItem> items;
  AssistantTranscript transcript = const AssistantTranscript();
  int eraseCount = 0;
  int setConsentCount = 0;

  @override
  Future<AssistantMemoryConsent> consent() async => AssistantMemoryConsent(
    memoryEnabled: memoryEnabled,
    webSearchEnabled: webSearchEnabled,
    version: memoryEnabled ? 'v1' : '',
  );

  @override
  Future<void> setConsent({
    required bool memory,
    bool webSearch = false,
  }) async {
    setConsentCount++;
    memoryEnabled = memory;
    webSearchEnabled = webSearch;
  }

  @override
  Future<List<AssistantMemoryItem>> recall({
    String query = '',
    int limit = 12,
  }) async => items;

  @override
  Future<String?> remember({
    required AssistantMemoryKind kind,
    required String key,
    required String value,
    AssistantMemorySource source = AssistantMemorySource.userSaid,
    double confidence = 0.8,
    bool isSecret = false,
    String? conversationId,
    String? locale,
  }) async {
    remembered.add((kind: kind, key: key, isSecret: isSecret));
    return 'm-${remembered.length}';
  }

  @override
  Future<int> forget({String? id, String? key}) async {
    items.removeWhere((item) => item.id == id || item.key == key);
    return 1;
  }

  @override
  Future<void> erase() async {
    eraseCount++;
    items = [];
  }

  @override
  Future<({String conversationId, String messageId})?> logMessage({
    String? conversationId,
    required String role,
    required String text,
    String? topic,
    List<String> sources = const [],
  }) async {
    logged.add((role: role, text: text));
    return (
      conversationId: conversationId ?? 'c-1',
      messageId: 'srv-${logged.length}',
    );
  }

  @override
  Future<AssistantTranscript> recentTranscript({int limit = 8}) async =>
      transcript;

  @override
  Future<void> recordFeedback({
    String? messageId,
    String? conversationId,
    required int rating,
    String? correction,
    String? question,
    String? answer,
  }) async {
    ratings.add(rating);
  }
}

/// A model that keeps what it was shown, so the prompt can be asserted.
class _RecordingClient implements LlmClient {
  final List<Map<String, String>> lastHistory = [];
  String lastSystem = '';
  bool lastLearn = true;
  bool lastPersonal = true;
  bool lastWebSearch = false;

  @override
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
    String questionKey = '',
    bool learn = true,
    bool personal = false,
    bool webSearch = false,
    bool captureKnowledgeGap = false,
  }) async {
    lastSystem = system;
    lastLearn = learn;
    lastPersonal = personal;
    lastWebSearch = webSearch;
    lastHistory
      ..clear()
      ..addAll(history);
    return const LlmReply(text: 'المتجر يفتح السابعة صباحاً', provider: 'groq');
  }
}

class _FakeRetrieval implements AssistantRetrieval {
  _FakeRetrieval(this.sources);

  final List<RetrievedSource> sources;
  int calls = 0;

  @override
  Future<List<RetrievedSource>> search(
    String query, {
    String? branchId,
    required String locale,
    int limit = 6,
  }) async {
    calls++;
    return sources;
  }
}

const _hoursSource = RetrievedSource(
  sourceType: 'article',
  sourceId: 'faq-hours',
  title: 'مواعيد العمل',
  body: 'من السابعة صباحاً حتى الحادية عشرة مساءً',
  score: 0.8,
);

AssistantMemoryItem _memory({
  required String id,
  required AssistantMemoryKind kind,
  required String key,
  String value = '',
}) => AssistantMemoryItem(
  id: id,
  kind: kind,
  key: key,
  value: value,
  confidence: 0.8,
  source: AssistantMemorySource.userSaid,
  lastSeen: DateTime(2026, 11, 5),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppLocale.instance.debugSet(AppLanguage.arabic);
  });

  Future<AssistantCubit> openChat(
    AssistantMemoryStore store, {
    AssistantRetrieval retrieval = const NoRetrieval(),
    LlmClient? llmClient,
  }) async {
    final cubit = AssistantCubit(
      catalog: const MockProductRepository(),
      orders: _NoOrders(),
      memoryStore: store,
      retrieval: retrieval,
      llmClient: llmClient,
    );
    addTearDown(cubit.close);
    await cubit.start();
    return cubit;
  }

  /// The island is read in the background so the greeting never waits; a test
  /// that needs it gives it the same room.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('the consent gate', () {
    test('nothing is written for a customer who never agreed', () async {
      final store = _FakeStore();
      final cubit = await openChat(store);

      await cubit.sendMessage('انا بحب اللاتيه');
      await settle();

      expect(store.logged, isEmpty);
      expect(store.remembered, isEmpty);
    });

    test('a stated preference is remembered once the customer agreed', () async {
      final store = _FakeStore(memoryEnabled: true);
      final cubit = await openChat(store);

      await cubit.sendMessage('انا بحب اللاتيه');
      await settle();

      expect(
        store.remembered.map((memory) => memory.key),
        contains('prefers:latte'),
      );
      expect(
        store.logged.map((turn) => turn.role),
        containsAllInOrder(['user', 'assistant']),
      );
    });

    test('taking consent back deletes the island', () async {
      final store = _FakeStore(
        memoryEnabled: true,
        items: [
          _memory(
            id: 'm-1',
            kind: AssistantMemoryKind.preference,
            key: 'prefers:لاتيه',
            value: 'انا بحب اللاتيه',
          ),
        ],
      );
      final cubit = await openChat(store);
      await settle();
      expect(cubit.state.memories, isNotEmpty);

      await cubit.setMemoryConsent(enabled: false);

      expect(store.eraseCount, 1);
      expect(cubit.state.memories, isEmpty);
    });

    test('a thumbs-up is recorded against the answer it is about', () async {
      final store = _FakeStore(memoryEnabled: true);
      final cubit = await openChat(store);

      await cubit.sendMessage('عايز قهوة سادة');
      await settle();
      final answer = cubit.state.messages.lastWhere(
        (message) => message.role == MessageRole.assistant,
      );

      await cubit.giveFeedback(answer.id, true);

      expect(store.ratings, contains(1));
    });
  });

  group('what the model is shown', () {
    test('retrieved documents replace the whole-catalogue dump', () async {
      final client = _RecordingClient();
      final cubit = await openChat(
        _FakeStore(),
        retrieval: _FakeRetrieval(const [_hoursSource]),
        llmClient: client,
      );

      // A question the local engine cannot answer, so the model is asked.
      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(client.lastSystem, contains('[faq-hours]'));
      expect(
        client.lastSystem,
        isNot(contains('Menu (name | category | price in SAR')),
        reason:
            'the menu is not dumped when the shop already answered the question',
      );
    });

    test('the answer keeps the document it was read from', () async {
      final cubit = await openChat(
        _FakeStore(),
        retrieval: _FakeRetrieval(const [_hoursSource]),
        llmClient: _RecordingClient(),
      );

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final answer = cubit.state.messages.lastWhere(
        (message) => message.role == MessageRole.assistant,
      );
      expect(answer.sources.map((source) => source.sourceId), [
        'faq-hours',
      ]);
    });

    test('a customer memory is only read back when consent is on', () async {
      final client = _RecordingClient();
      final store = _FakeStore(
        memoryEnabled: true,
        items: [
          _memory(
            id: 'm-1',
            kind: AssistantMemoryKind.preference,
            key: 'prefers:لاتيه',
            value: 'انا بحب اللاتيه',
          ),
        ],
      );
      final cubit = await openChat(
        store,
        retrieval: _FakeRetrieval(const [_hoursSource]),
        llmClient: client,
      );
      await settle();

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(client.lastSystem, contains('[preference] prefers:لاتيه'));
    });

    test('a personalised answer is never offered to the shared cache', () async {
      final client = _RecordingClient();
      final cubit = await openChat(
        _FakeStore(memoryEnabled: true),
        llmClient: client,
      );
      await settle();

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(client.lastPersonal, isTrue);
      expect(
        client.lastLearn,
        isFalse,
        reason: "an answer built from one customer is not every customer's",
      );
    });

    test('the internet is not read for a customer who did not allow it', () async {
      final client = _RecordingClient();
      final cubit = await openChat(_FakeStore(), llmClient: client);
      await settle();

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(client.lastWebSearch, isFalse);
    });

    test('the internet is read when the customer allowed it and the shop was silent', () async {
      final client = _RecordingClient();
      final cubit = await openChat(
        _FakeStore(webSearchEnabled: true),
        llmClient: client,
      );
      await settle();

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(client.lastWebSearch, isTrue);
    });

    test('the shop own pages answer first, so the web stays unread', () async {
      final client = _RecordingClient();
      final cubit = await openChat(
        _FakeStore(webSearchEnabled: true),
        retrieval: _FakeRetrieval(const [_hoursSource]),
        llmClient: client,
      );
      await settle();

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(client.lastSystem, contains('[faq-hours]'));
      expect(
        client.lastWebSearch,
        isFalse,
        reason: 'a question the shop can answer is not sent to a search engine',
      );
    });

    test('a new conversation is not handed the lines of the last one', () async {
      // The page opens a fresh chat every time, and the customer sees nothing of
      // the chat before it. An answer written from lines that are not on screen
      // would be the assistant remembering a conversation the customer closed.
      final client = _RecordingClient();
      final store = _FakeStore(memoryEnabled: true)
        ..transcript = AssistantTranscript(
          conversationId: 'c-old',
          messages: [
            LoggedMessage(
              id: 'l-1',
              role: 'user',
              text: 'كام سعر الموكا؟',
              at: DateTime(2026, 11, 1),
            ),
          ],
        );
      final cubit = await openChat(store, llmClient: client);
      await settle();

      await cubit.sendMessage('ايه رأيك في طقس اليوم؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        client.lastHistory,
        isNot(contains(equals({'role': 'user', 'content': 'كام سعر الموكا؟'}))),
      );
    });

    test('the conversation on screen is the history the model is given', () async {
      // Context inside one chat still holds: a follow-up is answered with the
      // question it follows, because that question is on the customer's screen.
      final client = _RecordingClient();
      final cubit = await openChat(
        _FakeStore(memoryEnabled: true),
        llmClient: client,
      );
      await settle();

      await cubit.sendMessage('الموكا بكام؟');
      await cubit.sendMessage('و فيه حجم كبير؟');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        client.lastHistory,
        contains(equals({'role': 'user', 'content': 'الموكا بكام؟'})),
      );
    });
  });

  group('the review screen', () {
    test('it loads the island and forgets one row on request', () async {
      final store = _FakeStore(
        memoryEnabled: true,
        items: [
          _memory(
            id: 'm-1',
            kind: AssistantMemoryKind.preference,
            key: 'prefers:لاتيه',
            value: 'انا بحب اللاتيه',
          ),
          _memory(
            id: 'm-2',
            kind: AssistantMemoryKind.fact,
            key: 'health:allergy',
          ),
        ],
      );
      final cubit = AssistantMemoryCubit(store: store);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.memories, hasLength(2));

      await cubit.forget(store.items.first);
      expect(cubit.state.memories, hasLength(1));
      expect(cubit.state.memories.single.key, 'health:allergy');
    });

    test('turning memory off from the review screen deletes it', () async {
      final store = _FakeStore(
        memoryEnabled: true,
        items: [
          _memory(
            id: 'm-1',
            kind: AssistantMemoryKind.fact,
            key: 'name:first',
            value: 'احمد',
          ),
        ],
      );
      final cubit = AssistantMemoryCubit(store: store);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.setMemoryEnabled(false);

      expect(store.eraseCount, 1);
      expect(cubit.state.memories, isEmpty);
      expect(cubit.state.consent.memoryEnabled, isFalse);
    });

    test('a signed-out device has no island to show', () async {
      final cubit = AssistantMemoryCubit(store: _FakeStore(), signedIn: false);
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.signedIn, isFalse);
    });
  });
}
