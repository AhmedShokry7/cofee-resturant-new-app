class LlmReply {
  const LlmReply({
    required this.text,
    this.topic = 'llm',
    this.provider,
  });

  final String text;
  final String topic;

  /// Where the answer came from: a provider name, or 'memory' when the
  /// assistant had already learned this question.
  final String? provider;

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
  });
}
