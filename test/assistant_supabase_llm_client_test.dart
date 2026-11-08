import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/assistant/data/llm/supabase_llm_client.dart';

void main() {
  test(
    'SupabaseLlmClient returns null when Supabase is not configured',
    () async {
      final client = const SupabaseLlmClient();
      final reply = await client.complete(
        system: 'system',
        history: const [],
        query: 'hello',
      );
      expect(reply, isNull);
    },
  );

  test('a missing provider is a cooldown, not a permanent latch', () {
    addTearDown(SupabaseLlmClient.debugResetProvider);

    // The backend said "not configured" a minute ago: the cooldown has passed,
    // so the app asks again (the operator may have fixed it without a deploy).
    SupabaseLlmClient.debugSetProviderMissing(
      until: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    expect(SupabaseLlmClient.providerMissing, isFalse);

    // Said just now: the app skips the call until the cooldown passes.
    SupabaseLlmClient.debugSetProviderMissing(
      until: DateTime.now().add(SupabaseLlmClient.providerCooldown),
    );
    expect(SupabaseLlmClient.providerMissing, isTrue);
  });
}
