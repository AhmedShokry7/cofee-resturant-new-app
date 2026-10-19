import 'package:flutter/foundation.dart';

import 'supabase_public_config.dart';

class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: SupabasePublicConfig.url,
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: SupabasePublicConfig.publishableKey,
  );

  static String get missingConfigurationMessage =>
      'Supabase public configuration is missing. Check the admin app configuration.';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static void debugLogConfiguration() {
    if (!kDebugMode) return;
    debugPrint('[AppConfig] supabase configured: $isSupabaseConfigured');
  }
}
