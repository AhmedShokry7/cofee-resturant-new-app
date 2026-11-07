import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';

class LlmReply {
  const LlmReply({
    required this.text,
    this.topic = 'llm',
    this.provider,
    this.sources = const [],
  });

  final String text;
  final String topic;

  /// Where the answer came from: a provider name, or 'memory' when the
  /// assistant had already learned this question.
  final String? provider;

  /// The shop documents this answer was read from, in the order the server
  /// found them. The customer sees them under the reply.
  final List<RetrievedSource> sources;

  /// True when the answer was remembered rather than freshly generated.
  bool get fromMemory => provider == 'memory';
}

/// Pluggable LLM backend. Returns null when it cannot answer so the caller
/// always falls back to the local engine.
abstract class LlmClient {
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,

    /// The normalized question, used to remember the answer and to look one
    /// up. Empty means "do not remember this".
    String questionKey = '',

    /// Whether the answer may be remembered.
    ///
    /// False for a question about the customer's own order or cart: the answer
    /// is true for that customer and false for the next one.
    bool learn = true,

    /// Whether this answer was written with one customer's own memories in the
    /// prompt. Such an answer is theirs alone: the server keeps it in their
    /// island and never in the shared cache every other customer reads.
    bool personal = false,

    /// Whether the customer allowed the assistant to read outside the shop for
    /// this question. The function answers with the pages it used, so the
    /// citation is the server's, not a link the model invented.
    bool webSearch = false,
  });
}
