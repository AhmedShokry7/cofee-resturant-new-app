import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/assistant/data/llm/supabase_llm_client.dart';

void main() {
  test('SupabaseLlmClient returns null when Supabase is not configured', () async {
    final client = const SupabaseLlmClient();
    final reply = await client.complete(
      system: 'system',
      history: const [],
      query: 'hello',
    );
    expect(reply, isNull);
  });
}