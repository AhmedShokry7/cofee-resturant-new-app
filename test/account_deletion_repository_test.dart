import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/profile/data/repositories/account_deletion_repository.dart';

void main() {
  test('creates a deletion request using the authenticated RPC identity only', () async {
    String? called;
    Map<String, dynamic>? params;
    final repository = AccountDeletionRepository(
      currentUserId: () => 'user-1',
      rpc: (name, arguments) async {
        called = name;
        params = arguments;
        return 'request-1';
      },
    );

    expect(await repository.requestDeletion(), 'request-1');
    expect(called, 'request_account_deletion');
    expect(params, isEmpty); // the RPC derives its subject from auth.uid().
  });

  test('does not issue a request without a signed-in identity', () async {
    var calls = 0;
    final repository = AccountDeletionRepository(
      currentUserId: () => null,
      rpc: (name, params) async {
        calls++;
        return null;
      },
    );

    await expectLater(repository.requestDeletion(), throwsStateError);
    expect(calls, 0);
  });
}
