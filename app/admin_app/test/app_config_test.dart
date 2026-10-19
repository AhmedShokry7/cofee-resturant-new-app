import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/config/app_config.dart';

void main() {
  test('public configuration is present by default', () {
    expect(AppConfig.isSupabaseConfigured, isTrue);
    expect(AppConfig.missingConfigurationMessage, isNotEmpty);
  });

  test('debugLogConfiguration does not throw', () {
    AppConfig.debugLogConfiguration();
  });
}
