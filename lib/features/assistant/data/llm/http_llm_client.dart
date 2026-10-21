import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:new_coffee/features/assistant/data/llm/llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_reply_sanitizer.dart';

/// OpenAI-compatible chat client (`POST {backendUrl}/v1/chat/completions`).
/// Any failure returns null and the local engine answers instead.
class HttpLlmClient implements LlmClient {
  const HttpLlmClient(this.config);

  final LlmConfig config;

  @override
  Future<LlmReply?> complete({
    required String system,
    required List<Map<String, String>> history,
    required String query,
    String questionKey = '',
    bool learn = true,
  }) async {
    if (!config.enabled) return null;
    try {
      final response = await http
          .post(
            Uri.parse('${config.backendUrl}/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              if (config.apiKey.isNotEmpty)
                'Authorization': 'Bearer ${config.apiKey}',
            },
            body: jsonEncode({
              'model': config.model,
              'temperature': 0.3,
              'max_tokens': 220,
              'messages': [
                {'role': 'system', 'content': system},
                ...history,
                {'role': 'user', 'content': query},
              ],
            }),
          )
          .timeout(config.timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      final message = choices?.isNotEmpty == true
          ? choices!.first as Map<String, dynamic>?
          : null;
      final content = (message?['message'] as Map<String, dynamic>?)?['content'];
      final text = content is String ? content.trim() : '';
      if (text.isEmpty) return null;
      return LlmReply(text: sanitizeLlmReply(text));
    } catch (_) {
      return null;
    }
  }
}
