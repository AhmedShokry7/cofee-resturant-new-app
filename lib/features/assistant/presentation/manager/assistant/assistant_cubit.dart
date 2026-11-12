import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/navigation/assistant_routes.dart';
import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversation_log.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversations.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_improvement_log.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_learned_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_language.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory_extractor.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';
import 'package:new_coffee/features/assistant/data/assistant_snapshot.dart';
import 'package:new_coffee/features/assistant/data/assistant_understanding.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/assistant/data/llm/http_llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/rag_context.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/weather/data/model/weather_model.dart';

part 'assistant_state.dart';

/// Performs the cart writes the customer explicitly authorised, and reports
/// whether they actually happened.
///
/// The cubit owns execution so a success line is only ever shown after the
/// write lands; the UI renders the conversation and never touches the cart.
/// Returning false (or throwing) means nothing was written, so the assistant
/// must not claim it was.
typedef CartExecutor = Future<bool> Function(
  List<CartAction> actions,
  AssistantSnapshot snapshot,
);

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({
    required this._catalog,
    required this._orders,
    this.branchId,
    LlmClient? llmClient,
    AssistantMemoryStore? memoryStore,
    AssistantRetrieval? retrieval,
    WeatherModel? Function()? currentWeather,
    this._cartExecutor,
    this.llmConfig = const LlmConfig(),
  }) : _llmClient = llmClient ?? HttpLlmClient(llmConfig),
       _store = memoryStore ?? const NoAssistantMemoryStore(),
       _retrieval = retrieval ?? const NoRetrieval(),
       _currentWeather = currentWeather,
       super(const AssistantState()) {
    _snapshot = const AssistantSnapshot.empty();
  }

  final CatalogRepository _catalog;
  final OrdersRepository _orders;

  /// The customer's own memory on the server, when they have agreed to it.
  final AssistantMemoryStore _store;

  /// The shop documents the assistant is allowed to read for one question.
  final AssistantRetrieval _retrieval;
  final WeatherModel? Function()? _currentWeather;

  /// The cart layer that performs authorised writes. Null when the host has no
  /// cart (tests, previews): a write that cannot happen is never called a success.
  final CartExecutor? _cartExecutor;

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
    future
        .then((loaded) {
          if (!isClosed) _snapshot = loaded;
        })
        .catchError((_) {
          // A catalogue that cannot be read is not an empty shop: mark the
          // sources failed so the answer says "unavailable", not "we have
          // nothing".
          if (!isClosed) {
            _snapshot = const AssistantSnapshot(
              products: [],
              productsState: DataState.failed,
              ordersState: DataState.failed,
            );
          }
        });
    return future;
  }

  AssistantMemory _memory = AssistantMemory();
  ConversationLog _log = ConversationLog();

  /// Every conversation this device has had, newest first — the list the
  /// history drawer shows.
  AssistantConversations _chats = AssistantConversations();

  /// The conversation on screen, on this device.
  String? _chatId;

  /// The conversation this chat is writing into on the server, once the first
  /// message is logged. It belongs to one conversation, not to the customer:
  /// opening the assistant starts a new chat, and a new chat is a new record on
  /// the server too — otherwise the answer would be filed under a conversation
  /// the customer is not looking at.
  String? _conversationId;

  /// Server message ids by local chat message id, so a thumbs-up can be
  /// attached to the answer it is about.
  final Map<String, String> _serverMessageIds = {};

  int _counter = 0;
  bool _isReturning = false;
  String? _firstName;
  Set<String> _lastCartIds = const {};
  AssistantImprovementLog _improvementLog = AssistantImprovementLog();

  /// Lessons learned from past conversations: phrasing → intent.
  AssistantLearnedIntents _learned = AssistantLearnedIntents();

  /// Guards against a second message while one is being answered.
  ///
  /// The chat's "typing" bubble is not used for this: it now means "waiting
  /// for the language model", and the local answer is instant.
  bool _answering = false;

  /// The newest question the assistant is still allowed to answer.
  ///
  /// A language-model answer takes seconds, and a customer who is not willing
  /// to wait sends another question while the first is on its way. The reply to
  /// the older one must then be thrown away, not printed under a question it
  /// never answered.
  int _turn = 0;

  String _nextId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

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
    _learned = await AssistantLearnedIntents.load();
    _chats = await AssistantConversations.load();
    await AssistantCatalog.load();
    if (isClosed) return;

    // Every arrival opens an empty chat. The conversations already had are in
    // the history drawer, where the customer chooses to read one; they are not
    // silently poured into the answer about to be given.
    _beginChat();

    // The catalogue and the order history follow in the background.
    unawaited(_ensureSnapshot());
    // So does the customer's memory: the greeting must not wait for it, and a
    // signed-out or silent customer has none to read.
    unawaited(_loadIsland());
  }

  /// Opens an empty conversation with the greeting in it.
  ///
  /// This is what "new chat" means, here and on the button: the older ones stay
  /// stored, and the server transcript starts again from nothing — so an answer
  /// is written from what is on screen and from this customer's own memory,
  /// never from a conversation they had already closed.
  void _beginChat() {
    _chatId = 'chat_${DateTime.now().microsecondsSinceEpoch}';
    _conversationId = null;
    // A new chat starts with no open question and no unconfirmed draft, so a
    // stray "أيوه" cannot execute an order left over from a previous chat.
    _memory.resetConversation();
    final arabic = _memory.totalChats > 0
        ? _memory.replyArabic
        : AppLocale.instance.isArabic;
    final returning = _isReturning || _memory.totalChats > 0;
    emit(
      state.copyWith(
        messages: [
          ChatMessage(
            id: _nextId(),
            role: MessageRole.assistant,
            text: arabic
                ? AssistantGreetings.chatGreetingAr(
                    isReturning: returning,
                    firstName: _firstName,
                    now: DateTime.now(),
                  )
                : AssistantGreetings.chatGreeting(
                    isReturning: returning,
                    firstName: _firstName,
                    now: DateTime.now(),
                  ),
          ),
        ],
        chats: _chats.all,
        activeChatId: _chatId,
        products: const [],
        typing: false,
        clearAction: true,
      ),
    );
  }

  /// The conversation on screen, written into the device list.
  Future<void> _saveOpenChat() async {
    final id = _chatId;
    if (id == null || isClosed) return;
    await _chats.save(
      AssistantConversation(
        id: id,
        title: AssistantConversation.titleOf(state.messages),
        updatedAt: DateTime.now(),
        messages: state.messages,
      ),
    );
    // The drawer lists the conversations, so a chat that just gained its first
    // question has to appear there without the customer closing anything.
    if (isClosed) return;
    emit(state.copyWith(chats: _chats.all, activeChatId: _chatId));
  }

  /// The history drawer's "new chat". The open conversation is filed first, so
  /// nothing already asked is lost when the next one starts.
  Future<void> newChat() async {
    await _saveOpenChat();
    if (isClosed) return;
    _beginChat();
  }

  /// Re-reads a conversation the customer already had, with the sources its
  /// answers were cited from.
  Future<void> openChat(String chatId) async {
    if (chatId == _chatId) return;
    final conversation = _chats.byId(chatId);
    if (conversation == null) return;
    await _saveOpenChat();
    if (isClosed) return;
    _chatId = conversation.id;
    // Its lines are on screen now, which is the only way this chat gets a past.
    _conversationId = null;
    emit(
      state.copyWith(
        messages: _bounded(conversation.messages),
        chats: _chats.all,
        activeChatId: conversation.id,
        products: const [],
        typing: false,
        clearAction: true,
      ),
    );
  }

  /// Deletes one conversation and returns it, so the screen can put it back
  /// when the customer changes their mind about the tap.
  Future<AssistantConversation?> deleteChat(String chatId) async {
    final conversation = _chats.byId(chatId);
    if (conversation == null) return null;
    await _chats.remove(chatId);
    if (isClosed) return conversation;
    emit(state.copyWith(chats: _chats.all));
    // The chat on screen went with the row that named it.
    if (_chatId == chatId) _beginChat();
    return conversation;
  }

  Future<void> restoreChat(AssistantConversation conversation) async {
    await _chats.restore(conversation);
    if (isClosed) return;
    emit(state.copyWith(chats: _chats.all));
  }

  /// Reads this customer's consent and, with it granted, the facts they have
  /// let the assistant keep about themselves.
  ///
  /// Nothing on the screen waits for this. The first answer that can use it is
  /// the language-model path, which is already a slow path.
  Future<void> _loadIsland() async {
    final consent = await _store.consent();
    if (isClosed) return;
    emit(state.copyWith(consent: consent));
    if (!consent.memoryEnabled) return;
    final items = await _store.recall(limit: 20);
    if (isClosed) return;
    emit(state.copyWith(memories: items));
  }

  /// The customer turning long-term memory on or off — the only place consent
  /// is ever decided, and it is theirs.
  ///
  /// Turning it off deletes, not disables: a memory the customer withdrew has
  /// no business sitting in a table waiting for them to change their mind.
  Future<void> setMemoryConsent({
    required bool enabled,
    bool webSearch = false,
  }) async {
    await _store.setConsent(memory: enabled, webSearch: webSearch);
    if (isClosed) return;
    emit(
      state.copyWith(
        // Two permissions, not one switch: letting the bot remember you is a
        // different yes from letting it leave the shop to read the web.
        consent: AssistantMemoryConsent(
          memoryEnabled: enabled,
          webSearchEnabled: webSearch,
          version: 'v1',
        ),
      ),
    );
    if (enabled) {
      await _loadIsland();
      return;
    }
    await _store.erase();
    if (isClosed) return;
    _conversationId = null;
    emit(state.copyWith(memories: const []));
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
    // This question is now the newest one the assistant may answer, whatever
    // was still on its way.
    _turn++;
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
        clearAction: true,
      ),
    );

    // Persist the user's question immediately, so closing the app before the
    // answer arrives cannot lose the conversation from local history.
    await _saveOpenChat();
    if (isClosed) return;

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

    // Who is allowed to answer this sentence, decided before anyone answers it.
    final reading = AssistantUnderstanding.analyse(
      text,
      snapshot: _snapshot,
      memory: _memory,
    );
    // Training replay: an identical (or near-identical) phrasing the offline
    // engine grounded before is answered with the intent it learned, without
    // re-scoring. A lesson the assistant already paid for is not paid again.
    final learned = _learned.lookup(text);
    final answer = AssistantEngine.answer(
      text,
      snapshot: _snapshot,
      memory: _memory,
      now: DateTime.now(),
      favoriteIds: favoriteIds,
      cartProductIds: cartProductIds,
      isReturning: _isReturning,
      firstName: _firstName,
      deviceIntent: learned ?? reading.deviceIntent,
    );
    _memory.recordTopic(answer.topic);
    // Learning from conversations: when the engine grounded a sentence the
    // keyword scorer itself could not place (typo-recovery or context did
    // it), the phrasing is filed with the intent that finally answered it.
    // Replays then skip the miss entirely next time.
    if (!reading.wantsLanguageModel &&
        answer.topic != 'fallback' &&
        detectIntent(text) == AssistantIntent.unknown) {
      final taughtIntent = _topicToIntent(answer.topic);
      if (taughtIntent != null) {
        unawaited(_learned.record(text, taughtIntent));
      }
    }
    // Every question the app cannot ground is a hole in what the assistant
    // knows, and the list of them is what the shop reads to fill the holes.
    // It used to be gated on the engine's own 'fallback' topic — which it
    // almost never reported, so the list stayed empty.
    if (reading.wantsLanguageModel) {
      unawaited(
        _improvementLog.recordUnknown(
          text,
          locale: AppLocale.instance.language.code,
        ),
      );
    }
    unawaited(_memory.save());

    final llmAvailable = llmConfig.enabled || SupabaseService.isConfigured;
    if (reading.wantsLanguageModel && llmAvailable) {
      // The canned line is kept in the pocket: it answers this question only
      // when the model cannot be reached. Showing it first is what made the
      // assistant look like it was answering a different sentence.
      final turn = _turn;
      emit(state.copyWith(typing: true));
      // The customer's line goes into the device history the moment they send
      // it: the answer may take seconds, and a chat they asked something in
      // must be in the drawer even while it is still being thought about.
      unawaited(_saveOpenChat());
      unawaited(_answerWithModel(text, reading, turn, answer));
      return;
    }
    await _emitLocalAnswer(text, answer, _turn);
  }

  /// Puts the offline engine's answer on screen and records the turn.
  ///
  /// A cart write the customer authorised is performed here, before the answer
  /// is shown: the success line is only ever printed once the write landed, and
  /// a failed write is reported as a failure rather than a silent success.
  Future<void> _emitLocalAnswer(
    String text,
    AssistantAnswer answer,
    int turn,
  ) async {
    if (isClosed || turn != _turn) return;
    // Only an explicitly authorised write may reach the cart. A proposal that
    // somehow still carries actions is dropped, never executed.
    final authorised = answer.actions
        .where((action) => action.approvedBy != null)
        .toList();
    var written = true;
    if (authorised.isNotEmpty) {
      written = await _writeToCart(authorised);
      if (isClosed || turn != _turn) return;
    }
    final arabic = AppLocale.instance.isArabic;
    final succeeded = authorised.isEmpty || written;
    final shownText = succeeded
        ? answer.text
        : (arabic
              ? 'تعذر تنفيذ الطلب على السلة دلوقتي، حاول تاني.'
              : "Couldn't update your cart right now, please try again.");
    final sourceId = succeeded ? answer.sourceId : 'cart-write-failed';
    unawaited(
      _log.logAssistant(
        shownText,
        intent: detectIntent(
          text,
          recentQueries: _memory.recentQueries,
          lastTopic: _memory.lastTopic,
        ).name,
        topic: answer.topic,
      ),
    );
    final assistantMessageId = _nextId();
    emit(
      state.copyWith(
        messages: _bounded([
          ...state.messages,
          ChatMessage(
            id: assistantMessageId,
            role: MessageRole.assistant,
            text: shownText,
            sourceId: sourceId,
          ),
        ]),
        typing: false,
        products: answer.products,
        navigateRoute: routeForAssistantDestination(answer.destination),
        navigateLabel: answer.navigateLabel,
      ),
    );
    // The server copy of this turn: the transcript, and whatever the customer
    // just told us about themselves. Behind the answer, never before it.
    unawaited(
      _recordTurn(
        text,
        answer: shownText,
        topic: answer.topic,
        assistantMessageId: assistantMessageId,
      ),
    );
    // And the device copy, which is what the history drawer lists tomorrow.
    unawaited(_saveOpenChat());
  }

  /// Runs the authorised cart writes and reports whether they happened.
  ///
  /// No cart layer, an unknown product, or a thrown error all mean the write
  /// did not land, so the caller must not announce a success.
  Future<bool> _writeToCart(List<CartAction> actions) async {
    final executor = _cartExecutor;
    if (executor == null) return false;
    try {
      return await executor(actions, _snapshot);
    } catch (_) {
      return false;
    }
  }

  /// The whole of one turn in the customer's own transcript, whoever answered:
  /// their line, then the reply, then anything they revealed about themselves.
  ///
  /// The order is the rule. An answer written while the chat still has no
  /// server id would open a second conversation for the same chat, so the
  /// reply waits for the line it answers.
  ///
  /// Consent is read every time, not cached in a field: the customer can switch
  /// memory off from the settings screen while this chat is still open, and the
  /// next message must not be stored.
  Future<void> _recordTurn(
    String text, {
    required String answer,
    required String topic,
    required String assistantMessageId,
    List<String> sources = const [],
  }) async {
    if (!await _recordUserTurn(text, topic)) return;
    await _recordAssistantTurn(answer, topic, assistantMessageId, sources);
    await _keepWhatTheySaid(text);
  }

  /// Writes the customer's line and adopts the conversation it was filed under.
  /// False means nothing else of this turn is stored.
  Future<bool> _recordUserTurn(String text, String topic) async {
    if (!state.consent.memoryEnabled) return false;
    final logged = await _store.logMessage(
      conversationId: _conversationId,
      role: 'user',
      text: text,
      topic: topic,
    );
    if (logged == null) return false;
    _conversationId = logged.conversationId;
    return true;
  }

  /// The intent whose answer carried [topic], or null for topics that are
  /// answers of knowledge or composition rather than an intent worth
  /// rehearsing.
  AssistantIntent? _topicToIntent(String topic) => switch (topic) {
    'suggest' => AssistantIntent.suggestDrink,
    'cart' => AssistantIntent.addToCart,
    'orders' => AssistantIntent.orderStatus,
    'prices' => AssistantIntent.showCoupons,
    'thanks' => AssistantIntent.thanks,
    'greeting' => AssistantIntent.greeting,
    'farewell' => AssistantIntent.farewell,
    'identity' => AssistantIntent.botIdentity,
    'memory' => AssistantIntent.memory,
    _ => null,
  };

  Future<void> _keepWhatTheySaid(String text) async {
    // The canonical name, not the one on screen: a preference filed as
    // "لاتيه" and one filed as "Latte" are the same taste, and the server
    // supersedes on the key.
    final menu = _snapshot.products
        .map(AssistantSnapshot.canonicalName)
        .toList();
    final extracted = AssistantMemoryExtractor.extract(text, products: menu);
    if (extracted.isEmpty) return;
    for (final memory in extracted) {
      await _store.remember(
        kind: memory.kind,
        key: memory.key,
        value: memory.value,
        confidence: memory.confidence,
        isSecret: memory.isSecret,
        conversationId: _conversationId,
        locale: AppLocale.instance.language.code,
      );
    }
    final items = await _store.recall(limit: 20);
    if (isClosed) return;
    emit(state.copyWith(memories: items));
  }

  /// Answers the sentences the app cannot ground, and keeps the offline
  /// engine's line for the case where the model cannot be reached.
  ///
  /// A reply to a question the customer has already replaced is dropped: the
  /// model takes seconds, and printing its answer under a newer question would
  /// put words in its mouth.
  Future<void> _answerWithModel(
    String text,
    AssistantUnderstanding reading,
    int turn,
    AssistantAnswer fallback,
  ) async {
    final sources = await _retrieval.search(
      text,
      branchId: branchId,
      locale: AppLocale.instance.language.code,
    );
    // The retrieved rows replace the whole-catalogue dump when they exist.
    // With nothing found the dump stays: a model shown the menu still beats a
    // model shown nothing.
    final shop = [
      if (sources.isNotEmpty) buildRetrievedContext(sources),
      // Keep the coffee education articles available even when the database
      // also returned menu rows for the same question.
      buildLocalContext(text, _memory),
      if (sources.isEmpty)
        buildLiveContext(
          _memory,
          snapshot: _snapshot,
          cartProductIds: _lastCartIds,
        ),
    ].where((part) => part.trim().isNotEmpty).join('\n\n');
    // Only a customer who said yes gets their past read back to the model.
    final personal = state.consent.memoryEnabled;
    final customer = personal
        ? AssistantMemoryExtractor.toPromptContext(state.memories)
        : '';
    // The internet is asked only when the shop's own pages and menu answered
    // nothing, the customer allowed it, and the question is not about their own
    // order — no search engine knows what that customer ordered.
    final webSearch =
        state.consent.webSearchEnabled &&
        sources.isEmpty &&
        !AssistantEngine.isPerishableQuestion(text);
    final reply = await _llmClient.complete(
      system:
          '${buildSystemPrompt(memory: _memory)}\n'
          '${buildWeatherContext(_currentWeather?.call())}\n'
          '${customer.isEmpty ? '' : '$customer\n'}'
          '$shop',
      history: _promptHistory(),
      query: text,
      // The question is remembered by the function, never by the app: a client
      // that could write the memory could poison it for every customer.
      questionKey: normalizeText(text),
      // An answer about the customer's own order goes stale the moment it is
      // served, so it is never learned. And an answer written from one
      // customer's memories is theirs alone — the shared cache is where the
      // next customer would otherwise read it.
      learn: reading.safeToLearn && !personal,
      personal: personal,
      webSearch: webSearch,
      captureKnowledgeGap:
          personal &&
          sources.isEmpty &&
          reading.knowledgeScore < AssistantEngine.factFloor &&
          !AssistantUnderstanding.isWeatherQuestion(text) &&
          AssistantUnderstanding.isCafeRelatedQuestion(text),
    );
    if (isClosed) return;
    // A newer question is on screen: this answer belongs to the one the
    // customer already replaced, so it is dropped with the typing bubble it
    // was waiting under — which the newer turn owns now.
    if (turn != _turn) return;
    if (reply == null) {
      // Nobody to ask. The offline engine's line is better than silence, and
      // it is the only reason it was computed.
      await _emitLocalAnswer(text, fallback, turn);
      return;
    }
    final replyText = AssistantSnapshot.preserveEnglishProductNames(
      reply.text,
      [
        ..._snapshot.products,
        for (final order in _snapshot.orders) order.product,
      ],
    );
    _memory.recordTopic(reply.topic);
    unawaited(_memory.save());
    unawaited(
      _log.logAssistant(
        replyText,
        intent: reading.intent.name,
        topic: reply.topic,
      ),
    );
    if (isClosed) return;
    final llmMessageId = _nextId();
    emit(
      state.copyWith(
        messages: _bounded([
          ...state.messages,
          ChatMessage(
            id: llmMessageId,
            role: MessageRole.assistant,
            text: replyText,
            sourceId: reply.fromMemory ? 'memory' : 'llm',
            // The shop rows the assistant read for this question, then any
            // page the function read from the web — the same page never twice.
            sources: dedupeSources([...sources, ...reply.sources]),
          ),
        ]),
        typing: false,
      ),
    );
    // The language model's lines are part of this conversation as well.
    unawaited(_saveOpenChat());
    unawaited(
      _recordTurn(
        text,
        answer: replyText,
        topic: reply.topic,
        assistantMessageId: llmMessageId,
        sources: (sources.isEmpty ? reply.sources : sources)
            .map((source) => source.sourceId)
            .toList(),
      ),
    );
  }

  /// The conversation on screen, oldest last and never longer than what the
  /// edge function accepts.
  ///
  /// A reopened chat gets its past from the lines the customer is looking at —
  /// the device history is read when a row is opened, never when a new chat
  /// starts, so no answer is written from a conversation they closed.
  List<Map<String, String>> _promptHistory() {
    final current = buildHistory(state.messages);
    const cap = 12;
    return current.length > cap
        ? current.sublist(current.length - cap)
        : current;
  }

  /// The language model's reply joins the customer's own transcript, with the
  /// documents it was read from.
  Future<void> _recordAssistantTurn(
    String text,
    String topic,
    String localMessageId,
    List<String> sources,
  ) async {
    if (!state.consent.memoryEnabled) return;
    final logged = await _store.logMessage(
      conversationId: _conversationId,
      role: 'assistant',
      text: text,
      topic: topic,
      sources: sources,
    );
    if (logged == null) return;
    _conversationId = logged.conversationId;
    _serverMessageIds[localMessageId] = logged.messageId;
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

  Future<void> giveFeedback(
    String messageId,
    bool liked, {
    String? correction,
  }) async {
    final messageIndex = state.messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (messageIndex < 0 || state.messages[messageIndex].feedback != null) {
      return;
    }
    final target = state.messages[messageIndex];
    var question = '';
    for (var index = messageIndex - 1; index >= 0; index--) {
      if (state.messages[index].role == MessageRole.user) {
        question = state.messages[index].text;
        break;
      }
    }
    final maySubmitForReview =
        AssistantUnderstanding.isCafeRelatedQuestion(question) &&
        !AssistantEngine.isPerishableQuestion(question) &&
        !mentionsWord(question, AssistantUnderstanding.ownOrderWords);
    final messages = state.messages.map((message) {
      if (message.id != messageId || message.feedback != null) return message;
      if (message.sourceId != null) {
        _memory.recordFeedback(message.sourceId!, liked);
      }
      return message.copyWith(feedback: liked ? 1 : -1);
    }).toList();
    emit(state.copyWith(messages: messages));
    await _memory.save();
    // The stored conversation carries the vote too, so reopening this chat
    // tomorrow shows the answer exactly as the customer left it.
    unawaited(_saveOpenChat());
    // The same vote, on the customer's own record: a rating is the one signal
    // that says the assistant's last answer was wrong, and it is what the
    // learning loop is built on.
    await _store.recordFeedback(
      messageId: _serverMessageIds[messageId],
      conversationId: _conversationId,
      rating: liked ? 1 : -1,
      correction: correction,
      question: maySubmitForReview ? question : null,
      answer: maySubmitForReview ? target.text : null,
    );
  }

  Future<void> recordProductInterest(ProductModel product) async {
    _memory.recordCategory(AssistantSnapshot.categoryKey(product), 2);
    _memory.recordProduct(product.id, 2);
    await _memory.save();
  }
}
