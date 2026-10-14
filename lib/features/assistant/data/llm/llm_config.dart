/// Hybrid LLM configuration.
///
/// Local engine answers everything by default. Set [backendUrl] to point at
/// YOUR backend (which holds the real LLM API key and exposes an
/// OpenAI-compatible `/v1/chat/completions` endpoint) to enable escalation.
///
/// The app never talks to a public LLM directly and never ships an API key.
class LlmConfig {
  const LlmConfig({
    this.backendUrl = '',
    this.model = 'coffee-assistant',
    this.timeout = const Duration(seconds: 12),
  });

  /// e.g. 'https://api.your-server.com'. Empty = Hybrid LLM disabled.
  final String backendUrl;
  final String model;
  final Duration timeout;

  bool get enabled => backendUrl.isNotEmpty;
}
