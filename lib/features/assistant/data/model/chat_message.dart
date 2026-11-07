import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';

enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.sourceId,
    this.sources = const [],
    this.feedback,
  });

  final String id;
  final MessageRole role;
  final String text;

  /// Knowledge source this answer came from, used for learning.
  final String? sourceId;

  /// The shop documents an answer was read from, shown under the reply so the
  /// customer can check it. Empty for anything the assistant knows by itself.
  final List<RetrievedSource> sources;

  /// +1 liked, -1 disliked, null not voted yet.
  final int? feedback;

  ChatMessage copyWith({int? feedback}) {
    return ChatMessage(
      id: id,
      role: role,
      text: text,
      sourceId: sourceId,
      sources: sources,
      feedback: feedback ?? this.feedback,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role == MessageRole.user ? 'user' : 'assistant',
    'text': text,
    if (sourceId != null) 'sourceId': sourceId,
    if (sources.isNotEmpty)
      'sources': [for (final source in sources) source.toJson()],
    if (feedback != null) 'feedback': feedback,
  };

  /// Null for anything unreadable: a half-written line is worse than no line,
  /// because the customer would read an answer that is not the one given.
  static ChatMessage? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id']?.toString();
    final text = value['text']?.toString();
    if (id == null || id.isEmpty || text == null || text.isEmpty) return null;
    final rawSources = value['sources'];
    return ChatMessage(
      id: id,
      role: value['role'] == 'assistant'
          ? MessageRole.assistant
          : MessageRole.user,
      text: text,
      sourceId: value['sourceId']?.toString(),
      sources: rawSources is List
          ? rawSources
                .map(RetrievedSource.fromJson)
                .whereType<RetrievedSource>()
                .toList()
          : const [],
      feedback: value['feedback'] is num
          ? (value['feedback'] as num).toInt()
          : null,
    );
  }
}
