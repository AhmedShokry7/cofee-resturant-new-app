import 'package:flutter/foundation.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_reply_sanitizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

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

  /// How long the app stops asking after the backend says "no provider".
  ///
  /// A 503 can be transient (a deploy in flight), and the operator can
  /// configure the provider server-side without redeploying the function — so
  /// this is a short cooldown, not a latch that disables the model for the
  /// whole app session.
  static const Duration providerCooldown = Duration(minutes: 5);

  static DateTime? _providerMissingUntil;

  /// Whether the backend recently said it has no provider.
  ///
  /// Exposed so the app can skip the call during the cooldown; it turns false
  /// again on its own once the cooldown passes.
  static bool get providerMissing {
    final until = _providerMissingUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  @visibleForTesting
  static void debugSetProviderMissing({required DateTime until}) =>
      _providerMissingUntil = until;

  @visibleForTesting
  static void debugResetProvider() => _providerMissingUntil = null;

  /// True when the edge function answered "no provider is configured".
  static bool _isProviderMissing(Object? details) {
    if (details is Map) {
      final message = details['error']?.toString().toLowerCase() ?? '';
      return message.contains('not configured');
    }
    return false;
  }

  @override
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
    String questionKey = '',
    bool learn = true,
    bool personal = false,
    bool webSearch = false,
    bool captureKnowledgeGap = false,
  }) async {
    if (!SupabaseService.isConfigured) return null;
    if (providerMissing) return null;
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
              // The question is remembered by the function, never by the app:
              // a client that could write the memory could poison it.
              if (questionKey.isNotEmpty) 'questionKey': questionKey,
              'learn': learn,
              // An answer built on this customer's own memories must not join
              // the cache the next customer reads.
              if (personal) 'personal': true,
              // Reading the web is allowed per customer, never for all of them.
              if (webSearch) 'webSearch': true,
              if (captureKnowledgeGap) 'captureKnowledgeGap': true,
            },
          )
          .timeout(timeout);
      if (response.status < 200 || response.status >= 300) return null;
      final data = response.data;
      if (data is! Map) return null;
      final text = data['text'];
      if (text is! String || text.trim().isEmpty) return null;
      final topic = data['topic'];
      final provider = data['provider'];
      return LlmReply(
        text: sanitizeLlmReply(text),
        topic: topic is String && topic.trim().isNotEmpty
            ? topic.trim()
            : 'llm',
        provider: provider is String && provider.trim().isNotEmpty
            ? provider.trim()
            : null,
        sources: _parseSources(data['sources']),
      );
    } on FunctionException catch (error) {
      if (error.status == 503 && _isProviderMissing(error.details)) {
        _providerMissingUntil = DateTime.now().add(providerCooldown);
      }
      return null;
    } catch (error, stackTrace) {
      // Never log prompts, tokens, or message content.
      debugPrint('SupabaseLlmClient: request failed (${error.runtimeType})');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}

/// The sources the function read to write this answer, in the shape the
/// database returns them.
List<RetrievedSource> _parseSources(dynamic raw) {
  if (raw is! List) return const [];
  final sources = <RetrievedSource>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final source = RetrievedSource.fromRow(entry.cast<String, dynamic>());
    if (source != null) sources.add(source);
  }
  return sources;
}
