import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/assistant/data/assistant_actions.dart';
import 'package:new_coffee/features/assistant/data/assistant_catalog.dart';
import 'package:new_coffee/features/assistant/data/assistant_composer.dart';
import 'package:new_coffee/features/assistant/data/assistant_conversation_log.dart';
import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_greetings.dart';
import 'package:new_coffee/features/assistant/data/assistant_intents.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/llm/http_llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/rag_context.dart';
import 'package:new_coffee/features/assistant/data/models/chat_message.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

part 'assistant_state.dart';

class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({LlmClient? llmClient, this.llmConfig = const LlmConfig()})
      : _llmClient = llmClient ?? HttpLlmClient(llmConfig),
        super(const AssistantState());

  final LlmClient _llmClient;
  final LlmConfig llmConfig;

  AssistantMemory _memory = AssistantMemory();
  ConversationLog _log = ConversationLog();
  int _counter = 0;
  bool _isReturning = false;
  String? _firstName;
  Set<String> _lastCartIds = const {};

  String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  List<ChatMessage> _bounded(List<ChatMessage> messages) {
    if (messages.length <= 100) return messages;
    return messages.sublist(messages.length - 100);
  }

  Future<void> start({bool isReturning = false, String? firstName}) async {
    _isReturning = isReturning;
    _firstName = firstName;
    _memory = await AssistantMemory.load();
    _log = await ConversationLog.load();
    await AssistantCatalog.load();
    if (isClosed) return;
    final arabic = _memory.replyArabic;
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
  }

  Future<void> sendMessage(
    String raw, {
    Set<String> favoriteIds = const {},
    Set<String> cartProductIds = const {},
    MessageChannel channel = MessageChannel.text,
  }) async {
    final text = raw.trim();
    if (text.isEmpty || state.typing) return;
    _memory.recordQuery(text);
    _lastCartIds = cartProductIds;
    // Stored verbatim: the exact user wording, ready for future learning.
    await _log.logUser(raw, channel: channel);
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(id: _nextId(), role: MessageRole.user, text: text),
        ],
        typing: true,
        quickReplies: const [],
        clearAction: true,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (isClosed) return;
    final answer = AssistantEngine.answer(
      text,
      memory: _memory,
      now: DateTime.now(),
      favoriteIds: favoriteIds,
      cartProductIds: cartProductIds,
      isReturning: _isReturning,
      firstName: _firstName,
    );
    _memory.recordTopic(answer.topic);
    await _memory.save();
    await _log.logAssistant(
      answer.text,
      intent: detectIntent(
        text,
        recentQueries: _memory.recentQueries,
        lastTopic: _memory.lastTopic,
      ).name,
      topic: answer.topic,
    );
    if (isClosed) return;
    final fallbackId = _nextId();
    emit(
      state.copyWith(
        messages: _bounded([
          ...state.messages,
          ChatMessage(
            id: fallbackId,
            role: MessageRole.assistant,
            text: answer.text,
            sourceId: answer.sourceId,
          ),
        ]),
        typing: false,
        quickReplies: answer.quickReplies,
        products: answer.products,
        navigateRoute: answer.navigateRoute,
        navigateLabel: answer.navigateLabel,
        cartActions: answer.actions,
      ),
    );
    if (answer.topic == 'fallback' && llmConfig.enabled) {
      await _tryLlmUpgrade(text, fallbackId);
    }
  }

  /// Called by the UI layer after executing [AssistantState.cartActions].
  /// Clears only the actions — navigation buttons stay visible.
  void clearCartActions() {
    if (state.cartActions.isEmpty || isClosed) return;
    emit(state.copyWith(cartActions: const []));
  }

  /// Hybrid escalation: only unknown queries reach the LLM, and only when a
  /// backend is configured. Any failure keeps the local fallback answer.
  Future<void> _tryLlmUpgrade(String text, String fallbackId) async {
    emit(state.copyWith(typing: true));
    final reply = await _llmClient.complete(
      system:
          '${buildSystemPrompt(memory: _memory)}\n${buildLocalContext(text, _memory)}\n${buildLiveContext(_memory, cartProductIds: _lastCartIds)}',
      history: buildHistory(state.messages),
      query: text,
    );
    if (isClosed) return;
    if (reply == null) {
      emit(state.copyWith(typing: false));
      return;
    }
    _memory.recordTopic(reply.topic);
    await _memory.save();
    if (isClosed) return;
    emit(
      state.copyWith(
        messages: _bounded(
          state.messages
              .map(
                (message) => message.id == fallbackId
                    ? ChatMessage(
                        id: message.id,
                        role: MessageRole.assistant,
                        text: reply.text,
                        sourceId: 'llm',
                      )
                    : message,
              )
              .toList(),
        ),
        typing: false,
      ),
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
    _memory.recordCategory(product.category, 2);
    _memory.recordProduct(product.id, 2);
    await _memory.save();
  }
}
