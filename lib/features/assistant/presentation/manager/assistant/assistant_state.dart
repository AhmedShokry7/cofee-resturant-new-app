part of 'assistant_cubit.dart';

class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.typing = false,
    this.products = const [],
    this.navigateRoute,
    this.navigateLabel,
    this.consent = const AssistantMemoryConsent(),
    this.memories = const [],
    this.chats = const [],
    this.activeChatId,
  });

  final List<ChatMessage> messages;
  final bool typing;
  final List<ProductModel> products;
  final String? navigateRoute;
  final String? navigateLabel;

  /// The conversations on screen are the ones in [chats] minus this id, which is
  /// how the history drawer marks the row the customer is already reading.
  final String? activeChatId;

  /// Every conversation this device has had, newest first — including the one on
  /// screen once it has a question in it.
  final List<AssistantConversation> chats;

  /// What this customer has agreed to have remembered about them. False by
  /// default: the assistant has no memory of a customer until they say so.
  final AssistantMemoryConsent consent;

  /// The customer's own long-term memories, for the review screen and for the
  /// answers that may use them.
  final List<AssistantMemoryItem> memories;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? typing,
    List<ProductModel>? products,
    String? navigateRoute,
    String? navigateLabel,
    AssistantMemoryConsent? consent,
    List<AssistantMemoryItem>? memories,
    List<AssistantConversation>? chats,
    String? activeChatId,
    bool clearAction = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      typing: typing ?? this.typing,
      products: products ?? this.products,
      navigateRoute: clearAction ? null : navigateRoute ?? this.navigateRoute,
      navigateLabel: clearAction ? null : navigateLabel ?? this.navigateLabel,
      consent: consent ?? this.consent,
      memories: memories ?? this.memories,
      chats: chats ?? this.chats,
      activeChatId: activeChatId ?? this.activeChatId,
    );
  }
}
