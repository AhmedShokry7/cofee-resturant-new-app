import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/navigation/assistant_routes.dart';
import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_composer.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversation_log.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_improvement_log.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/assistant/data/llm/http_llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/rag_context.dart';
import 'package:new_coffee/features/assistant/data/models/chat_message.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({
    required this._catalog,
    required OrdersRepository orders,
    this.branchId,
    LlmClient? llmClient,
    this.llmConfig = const LlmConfig(),
  })  : _orders = orders,
        _llmClient = llmClient ?? HttpLlmClient(llmConfig),
        super(const AssistantState()) {
    _snapshot = const AssistantSnapshot.empty();
  }

  final CatalogRepository _catalog;
  final OrdersRepository _orders;

  /// Branch used for catalogue prices in the assistant snapshot.
  String? branchId;

  Future<void> setBranch(String? branchId) async {
    if (branchId == this.branchId) return;
    this.branchId = branchId;
    // The prices changed, so the catalogue has to be read again.
    _snapshotFuture = null;
    _snapshot = await _ensureSnapshot();
  }
  final LlmClient _llmClient;
  final LlmConfig llmConfig;
  late AssistantSnapshot _snapshot;

  /// The catalogue load that is on its way, if any.
  ///
  /// Opening the assistant must never wait for the network: the greeting goes
  /// out first and the catalogue arrives while the customer reads it. A
  /// question that arrives before the catalogue does waits for it, because an
  /// answer computed against an empty menu would be worse than a short wait.
  Future<AssistantSnapshot>? _snapshotFuture;

  /// Repository-backed catalogue context used for the current chat session.
  AssistantSnapshot get snapshot => _snapshot;

  /// Loads the catalogue and the order history, once.
  Future<AssistantSnapshot> _ensureSnapshot() {
    final pending = _snapshotFuture;
    if (pending != null) return pending;
    final future = AssistantSnapshot.load(
      catalog: _catalog,
      activeOrders: () => _orders.listOrders(status: OrderStatus.active),
      branchId: branchId,
    );
    _snapshotFuture = future;
    future.then((loaded) {
      if (!isClosed) _snapshot = loaded;
    }).catchError((_) {
      // A catalogue that cannot be read leaves the assistant with an empty
      // menu, which is a valid answer rather than a crash.
      if (!isClosed) _snapshot = const AssistantSnapshot.empty();
    });
    return future;
  }

  AssistantMemory _memory = AssistantMemory();
  ConversationLog _log = ConversationLog();
  int _counter = 0;
  bool _isReturning = false;
  String? _firstName;
  Set<String> _lastCartIds = const {};
  AssistantImprovementLog _improvementLog = AssistantImprovementLog();

  /// Guards against a second message while one is being answered.
  ///
  /// The chat's "typing" bubble is not used for this: it now means "waiting
  /// for the language model", and the local answer is instant.
  bool _answering = false;

  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  List<ChatMessage> _bounded(List<ChatMessage> messages) {
    if (messages.length <= 100) return messages;
    return messages.sublist(messages.length - 100);
  }

  Future<void> start({bool isReturning = false, String? firstName}) async {
    _isReturning = isReturning;
    _firstName = firstName;

    // Everything here is on the device: SharedPreferences and the in-app
    // knowledge table. It costs milliseconds, so the greeting can honour the
    // language the customer learned without making them wait.
    _memory = await AssistantMemory.load();
    _log = await ConversationLog.load();
    _improvementLog = await AssistantImprovementLog.load();
    await AssistantCatalog.load();
    if (isClosed) return;

    final arabic = _memory.totalChats > 0
        ? _memory.replyArabic
        : AppLocale.instance.isArabic;
    final returning = isReturning || _memory.totalChats > 0;
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: _nextId(),
            role: MessageRole.assistant,
            text: arabic
                ? AssistantGreetings.chatGreetingAr(
                    isReturning: returning,
                    firstName: firstName,
                    now: DateTime.now(),
                  )
                : AssistantGreetings.chatGreeting(
                    isReturning: returning,
                    firstName: firstName,
                    now: DateTime.now(),
                  ),
          ),
        ],
        quickReplies: arabic
            ? AssistantComposer.quickRepliesAr
            : AssistantEngine.defaultQuickReplies,
      ),
    );

    // The catalogue and the order history follow in the background.
    unawaited(_ensureSnapshot());
  }

  Future<void> sendMessage(
    String raw, {
    Set<String> favoriteIds = const {},
    Set<String> cartProductIds = const {},
    MessageChannel channel = MessageChannel.text,
  }) async {
    final text = raw.trim();
    if (text.isEmpty || _answering) return;
    _answering = true;
    try {
      await _send(
        raw,
        text,
        favoriteIds: favoriteIds,
        cartProductIds: cartProductIds,
        channel: channel,
      );
    } finally {
      _answering = false;
    }
  }

  Future<void> _send(
    String raw,
    String text, {
    required Set<String> favoriteIds,
    required Set<String> cartProductIds,
    required MessageChannel channel,
  }) async {
    _memory.recordQuery(text);
    _lastCartIds = cartProductIds;

    // The customer's own message appears at once. Everything after this point
    // is the answer, and the answer is local.
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(id: _nextId(), role: MessageRole.user, text: text),
        ],
        quickReplies: const [],
        clearAction: true,
      ),
    );

    // Stored verbatim: the exact user wording, ready for future learning.
    // Writing to disk must never delay the answer.
    unawaited(_log.logUser(raw, channel: channel));

    // The catalogue may still be on its way. Answering against an empty menu
    // would be worse than the short wait.
    try {
      await _ensureSnapshot();
    } catch (_) {
      // An empty catalogue still answers, just with less to say.
    }
    if (isClosed) return;

    final answer = AssistantEngine.answer(
      text,
      snapshot: _snapshot,
      memory: _memory,
      now: DateTime.now(),
      favoriteIds: favoriteIds,
      cartProductIds: cartProductIds,
      isReturning: _isReturning,
      firstName: _firstName,
    );
    _memory.recordTopic(answer.topic);
    // The questions the local engine could not answer are the ones the
    // language model had to take, and they are exactly the list of what the
    // local engine still needs to learn.
    //
    // The topic is 'fallback', not 'unknown': the engine never reports
    // 'unknown', so the log used to stay empty and the loop never started.
    if (answer.topic == 'fallback') {
      unawaited(
        _improvementLog.recordUnknown(
          text,
          locale: AppLocale.instance.language.code,
        ),
      );
    }
    unawaited(_memory.save());
    unawaited(
      _log.logAssistant(
        answer.text,
        intent: detectIntent(
          text,
          recentQueries: _memory.recentQueries,
          lastTopic: _memory.lastTopic,
        ).name,
        topic: answer.topic,
      ),
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: _bounded([
          ...state.messages,
          ChatMessage(
            id: _nextId(),
            role: MessageRole.assistant,
            text: answer.text,
            sourceId: answer.sourceId,
          ),
        ]),
        typing: false,
        quickReplies: answer.quickReplies,
        products: answer.products,
        navigateRoute: routeForAssistantDestination(answer.destination),
        navigateLabel: answer.navigateLabel,
        cartActions: answer.actions,
      ),
    );
    final llmAvailable =
        llmConfig.enabled || SupabaseService.isConfigured;
    if (answer.topic == 'fallback' && llmAvailable) {
      unawaited(_tryLlmUpgrade(text));
    }
  }

  /// Called by the UI layer after executing [AssistantState.cartActions].
  /// Clears only the actions — navigation buttons stay visible.
  void clearCartActions() {
    if (state.cartActions.isEmpty || isClosed) return;
    emit(state.copyWith(cartActions: const []));
  }

  /// Hybrid escalation: only unknown queries reach the LLM, and only when a
  /// backend is configured.
  ///
  /// The local answer stays on screen. The model's reply arrives as its own
  /// message, so nothing the customer already read is taken away: the model
  /// adds to the answer instead of overwriting it. It is a fallback, not the
  /// main path — it is slow, and it does not understand everyday Arabic.
  Future<void> _tryLlmUpgrade(String text) async {
    emit(state.copyWith(typing: true));
    final reply = await _llmClient.complete(
      system:
          '${buildSystemPrompt(memory: _memory)}\n${buildLocalContext(text, _memory)}\n${buildLiveContext(_memory, snapshot: _snapshot, cartProductIds: _lastCartIds)}',
      history: buildHistory(state.messages),
      query: text,
      // The question is remembered by the function, never by the app: a client
      // that could write the memory could poison it for every customer.
      questionKey: normalizeText(text),
      // An answer about the customer's own order goes stale the moment it is
      // served, so it is never learned.
      learn: !AssistantEngine.isPerishableQuestion(text),
    );
    if (isClosed) return;
    if (reply == null) {
      emit(state.copyWith(typing: false));
      return;
    }
    _memory.recordTopic(reply.topic);
    unawaited(_memory.save());
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: _bounded([
          ...state.messages,
          ChatMessage(
            id: _nextId(),
            role: MessageRole.assistant,
            text: reply.text,
            sourceId: reply.fromMemory ? 'memory' : 'llm',
          ),
        ]),
        typing: false,
      ),
    );
  }

  /// Re-sends the last user message (best-effort retry). Avoids duplicate
  /// side effects by relying on the existing sendMessage guards.
  Future<void> retryLast({
    Set<String> favoriteIds = const {},
    Set<String> cartProductIds = const {},
  }) async {
    final lastUser = state.messages.lastWhere(
      (message) => message.role == MessageRole.user,
      orElse: () => const ChatMessage(id: '', role: MessageRole.user, text: ''),
    );
    if (lastUser.text.trim().isEmpty || _answering) return;
    await sendMessage(
      lastUser.text,
      favoriteIds: favoriteIds,
      cartProductIds: cartProductIds,
    );
  }

  Future<void> giveFeedback(String messageId, bool liked) async {
    final messages = state.messages.map((message) {
      if (message.id != messageId || message.feedback != null) return message;
      if (message.sourceId != null) {
        _memory.recordFeedback(message.sourceId!, liked);
      }
      return message.copyWith(feedback: liked ? 1 : -1);
    }).toList();
    emit(state.copyWith(messages: messages));
    await _memory.save();
  }

  Future<void> recordProductInterest(ProductModel product) async {
    _memory.recordCategory(
      AssistantSnapshot.categoryKey(product),
      2,
    );
    _memory.recordProduct(product.id, 2);
    await _memory.save();
  }
}
