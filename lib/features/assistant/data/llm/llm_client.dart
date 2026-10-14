class LlmReply {
  const LlmReply({required this.text, this.topic = 'llm'});

  final String text;
  final String topic;
}

/// Pluggable LLM backend. Returns null when it cannot answer so the caller
/// always falls back to the local engine.
abstract class LlmClient {
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
  });
}
