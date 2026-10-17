import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Every value is injected at build time with `--dart-define`, so nothing is
/// hard-coded in the repository and no key can be committed by accident:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> \
///     --dart-define=PASSWORD_RECOVERY_REDIRECT=<redirect-url>
///
/// `SUPABASE_PUBLISHABLE_KEY` is the public "anon" role and is safe to ship.
/// The `service_role` key must never reach the client (DATABASE_SPEC.md 1.5).
///
/// A build without the defines still runs: [isSupabaseConfigured] is false and
/// the app falls back to its local data instead of serving fabricated results.
class AppConfig {
  AppConfig._();

  /// Supabase project URL. Injected with `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Publishable (public) key. Injected with
  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Where Supabase should send the user after they follow a password-reset
  /// link. Must be registered under Auth -> URL Configuration in the dashboard,
  /// otherwise the redirect is rejected and no recovery session is created.
  /// Injected with `--dart-define=PASSWORD_RECOVERY_REDIRECT=...`.
  static const String passwordRecoveryRedirect =
      String.fromEnvironment('PASSWORD_RECOVERY_REDIRECT');

  /// Shown when the app was built without the Supabase defines. Names the
  /// missing inputs, never any value.
  static String get missingConfigurationMessage =>
      'Missing configuration. Build with '
      '--dart-define=SUPABASE_URL=... and '
      '--dart-define=SUPABASE_PUBLISHABLE_KEY=...';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isRecoveryRedirectConfigured =>
      passwordRecoveryRedirect.isNotEmpty;

  /// Logged only in debug mode. Never prints a key value.
  static void debugLogConfiguration() {
    if (!kDebugMode) return;
    debugPrint('[AppConfig] supabase configured: $isSupabaseConfigured');
  }
}