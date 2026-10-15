import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/repositories/notification_repository.dart';

/// Anonymous notification access must stop before Supabase. Authenticated row
/// isolation is covered by the database acceptance suite.
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');
  const needsSetup =
      'Needs --dart-define SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and '
      'SCHEMAS_EXPOSED=true';

  final String? skip =
      (!AppConfig.isSupabaseConfigured || !schemasExposed) ? needsSetup : null;

  setUpAll(() async {
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    await Supabase.instance.client.auth.signOut();
  });

  test('anonymous notification reads and writes require sign-in', () async {
    const repository = NotificationsRepositoryImpl();

    await expectLater(
      repository.listNotifications(),
      throwsA(isA<NotificationSignInRequiredException>()),
    );
    await expectLater(
      repository.markRead(['00000000-0000-0000-0000-000000000000']),
      throwsA(isA<NotificationSignInRequiredException>()),
    );
  }, skip: skip);
}
