import 'package:new_coffee/features/assistant/data/assistant_engine.dart';
import 'package:new_coffee/features/assistant/data/assistant_memory.dart';
import 'package:new_coffee/features/assistant/data/models/chat_message.dart';

String buildSystemPrompt({required AssistantMemory memory}) {
  final buffer = StringBuffer(
    'You are the friendly in-app assistant of a coffee shop app. '
    'Answer briefly in the user language, max 3 short sentences. '
    'Only use the provided local knowledge; never invent prices, hours or policies. '
    'If you are not sure, say so and offer the in-app help options. ',
  );
  final top = memory.topCategory();
  if (top != null) buffer.write('The user enjoys $top. ');
  if (memory.totalChats > 0) {
    buffer.write('They have chatted ${memory.totalChats} times before. ');
  }
  return buffer.toString();
}

List<Map<String, String>> buildHistory(
  List<ChatMessage> messages, {
  int maxTurns = 4,
}) {
  final meaningful = messages
      .where((message) => message.text.trim().isNotEmpty)
      .toList();
  final tail = meaningful.length > maxTurns * 2
      ? meaningful.sublist(meaningful.length - maxTurns * 2)
      : meaningful;
  return [
    for (final message in tail)
      {
        'role': message.role == MessageRole.user ? 'user' : 'assistant',
        'content': message.text,
      },
  ];
}

String buildLocalContext(
  String query,
  AssistantMemory memory, {
  int limit = 3,
}) {
  final ranked = AssistantEngine.rankArticles(query, memory, limit: limit);
  if (ranked.isEmpty) return 'No local knowledge matched.';
  final buffer = StringBuffer('Local knowledge (most relevant first):\n');
  for (final entry in ranked) {
    var body = entry.$1.body;
    if (body.length > 400) body = '${body.substring(0, 400)}…';
    buffer.writeln('- ${entry.$1.title}: $body');
  }
  return buffer.toString();
}
