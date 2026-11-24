import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/auth/data/repositories/supabase_auth_repository.dart';

// Runtime probe: uses the exact app initialization and repository code path
// against the live project. The token is passed via environment variable
// INVITE_TOKEN so it never appears in this file or in logs.
void main() {
  test('real app code path: init + lookupInvitation', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SupabaseService.init();
    expect(SupabaseService.isReady, isTrue, reason: 'Supabase init failed');
    const token = String.fromEnvironment('INVITE_TOKEN');
    expect(token.isNotEmpty, isTrue, reason: 'INVITE_TOKEN not set');
    final repo = SupabaseAuthRepository();
    final answer = await repo.lookupInvitation(token);
    // ignore: avoid_print
    print(
      'PROBE outcome=${answer.outcome} found=${answer.isFound} '
      'email=${answer.preview?.email ?? ''} '
      'role=${answer.preview?.roleName ?? ''}',
    );
    expect(answer.isFound, isTrue);
  });
}
