/// Hybrid LLM configuration.
///
/// Local engine answers everything by default. Set [backendUrl] to point at
/// YOUR backend (which holds the real LLM API key and exposes an
/// OpenAI-compatible `/v1/chat/completions` endpoint) to enable escalation.
///
/// Free options that speak the same protocol (see guide in README notes):
/// - Ollama on your own machine (fully free + open-source):
///   backendUrl 'http://10.0.2.2:11434' (Android emulator), model 'qwen2.5',
///   no key needed. Best Arabic open model family: Qwen.
/// - OpenRouter free models: backendUrl 'https://openrouter.ai/api',
///   model `your-model:free`, apiKey 'sk-or-...' (free signup).
/// - Groq free tier: backendUrl 'https://api.groq.com/openai',
///   model 'llama-3.3-70b-versatile', apiKey 'gsk_...' (free signup).
///
/// The app never talks to a public LLM directly with a shipped secret in
/// production — prefer your own backend or Firebase AI Logic there.
class LlmConfig {
  const LlmConfig({
    this.backendUrl = '',
    this.model = 'coffee-assistant',
    this.apiKey = '',
    this.timeout = const Duration(seconds: 12),
  });

  /// e.g. 'https://api.your-server.com'. Empty = Hybrid LLM disabled.
  final String backendUrl;
  final String model;

  /// Optional bearer token (OpenRouter / Groq). Empty = no auth header.
  final String apiKey;
  final Duration timeout;

  bool get enabled => backendUrl.isNotEmpty;
}
