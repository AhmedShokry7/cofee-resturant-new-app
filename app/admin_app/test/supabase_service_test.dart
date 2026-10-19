import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/services/supabase_service.dart';

void main() {
  tearDown(() {
    SupabaseService.debugReset();
  });

  test('service is not ready before initialisation', () {
    SupabaseService.debugReset();
    expect(SupabaseService.isReady, isFalse);
    expect(SupabaseService.isSignedIn, isFalse);
  });

  test('client getter throws before initialisation', () {
    SupabaseService.debugReset();
    expect(() => SupabaseService.client, throwsStateError);
  });
}
