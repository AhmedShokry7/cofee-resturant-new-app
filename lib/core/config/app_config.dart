import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Everything here arrives through `--dart-define`, so no value is ever
/// hard-coded in the repository and no secret can be committed by accident.
///
///   flutter run \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=...
///
/// The service_role key must NEVER be passed here. It bypasses RLS and must
/// stay on the server (DATABASE_SPEC.md section 1.5).
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Where Supabase should send the user after they follow a password reset
  /// link. Must be registered under Auth -> URL Configuration in the dashboard,
  /// otherwise the redirect is rejected and no recovery session is created.
  static const String passwordRecoveryRedirect =
      String.fromEnvironment('PASSWORD_RECOVERY_REDIRECT');

  /// The app was built without Supabase credentials. The app still runs, using
  /// the local mock repositories, so the UI stays reviewable offline.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isRecoveryRedirectConfigured =>
      passwordRecoveryRedirect.isNotEmpty;

  /// Human-readable reason, shown once in debug rather than failing silently.
  static String get missingConfigurationMessage {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    return 'Missing build-time configuration: ${missing.join(', ')}.\n'
        'Run with:\n'
        '  flutter run --dart-define=SUPABASE_URL=<url> '
        '--dart-define=SUPABASE_PUBLISHABLE_KEY=<key>';
  }

  /// Logged only in debug mode. Never prints a key value.
  static void debugLogConfiguration() {
    if (!kDebugMode) return;
    debugPrint('[AppConfig] supabase configured: $isSupabaseConfigured '
        '(url host: ${_hostOf(supabaseUrl)})');
  }

  static String _hostOf(String url) {
    if (url.isEmpty) return '<none>';
    final uri = Uri.tryParse(url);
    return uri == null || uri.host.isEmpty ? '<invalid>' : uri.host;
  }
}