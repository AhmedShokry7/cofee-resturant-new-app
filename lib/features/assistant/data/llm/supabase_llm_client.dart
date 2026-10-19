import 'package:flutter/foundation.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';

/// LLM client that talks to the project's own Supabase Edge Function
/// (`ai-assistant`) instead of a provider directly. The provider API key
/// stays server-side; the Flutter app only sends the conversation and
/// receives the assistant reply.
class SupabaseLlmClient implements LlmClient {
  const SupabaseLlmClient({
    this.functionName = 'ai-assistant',
    this.timeout = const Duration(seconds: 15),
  });

  final String functionName;
  final Duration timeout;

  @override
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
  }) async {
    if (!SupabaseService.isConfigured) return null;
    try {
      final client = SupabaseService.client;
      final response = await client.functions
          .invoke(
            functionName,
            body: <String, dynamic>{
              'messages': <Map<String, String>>[
                <String, String>{'role': 'system', 'content': system},
                ...history,
                <String, String>{'role': 'user', 'content': query},
              ],
            },
          )
          .timeout(timeout);
      if (response.status < 200 || response.status >= 300) return null;
      final data = response.data;
      if (data is! Map) return null;
      final text = data['text'];
      if (text is! String || text.trim().isEmpty) return null;
      final topic = data['topic'];
      return LlmReply(
        text: text.trim(),
        topic: topic is String && topic.trim().isNotEmpty ? topic.trim() : 'llm',
      );
    } catch (error, stackTrace) {
      // Never log prompts, tokens, or message content.
      debugPrint('SupabaseLlmClient: request failed (${error.runtimeType})');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}