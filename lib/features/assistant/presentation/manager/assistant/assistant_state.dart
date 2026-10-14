part of 'assistant_cubit.dart';

class AssistantState {
  const AssistantState({
    this.messages = const [],
    this.typing = false,
    this.quickReplies = const [],
    this.products = const [],
    this.navigateRoute,
    this.navigateLabel,
    this.cartActions = const [],
  });

  final List<ChatMessage> messages;
  final bool typing;
  final List<String> quickReplies;
  final List<ProductModel> products;
  final String? navigateRoute;
  final String? navigateLabel;

  /// Pending tool calls (e.g. add-to-cart) for the UI layer to execute once.
  final List<CartAction> cartActions;

  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? typing,
    List<String>? quickReplies,
    List<ProductModel>? products,
    String? navigateRoute,
    String? navigateLabel,
    List<CartAction>? cartActions,
    bool clearAction = false,
  }) {
    return AssistantState(
      messages: messages ?? this.messages,
      typing: typing ?? this.typing,
      quickReplies: quickReplies ?? this.quickReplies,
      products: products ?? this.products,
      navigateRoute: clearAction ? null : navigateRoute ?? this.navigateRoute,
      navigateLabel: clearAction ? null : navigateLabel ?? this.navigateLabel,
      cartActions: clearAction ? const [] : cartActions ?? this.cartActions,
    );
  }
}
