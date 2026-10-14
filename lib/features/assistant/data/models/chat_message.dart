enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.sourceId,
    this.feedback,
  });

  final String id;
  final MessageRole role;
  final String text;

  /// Knowledge source this answer came from, used for learning.
  final String? sourceId;

  /// +1 liked, -1 disliked, null not voted yet.
  final int? feedback;

  ChatMessage copyWith({int? feedback}) {
    return ChatMessage(
      id: id,
      role: role,
      text: text,
      sourceId: sourceId,
      feedback: feedback ?? this.feedback,
    );
  }
}
