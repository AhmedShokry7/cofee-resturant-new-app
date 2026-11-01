import 'package:flutter/foundation.dart';

import 'package:new_coffee/core/locale/app_strings.dart';

import 'supabase_public_config.dart';

/// Build-time configuration.
///
/// The app's public Supabase URL/key have safe project defaults, so ordinary
/// IDE and CLI runs work without extra arguments. Build-time defines override
/// those defaults when a different project is needed:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key> \
///   --dart-define=PASSWORD_RECOVERY_REDIRECT=<redirect-url>
/// ```
///
/// `SUPABASE_PUBLISHABLE_KEY` is the public "anon" role and is safe to ship.
/// The `service_role` key must never reach the client (DATABASE_SPEC.md 1.5).
///
/// A build without defines uses the public project defaults, so ordinary
/// Debug launches remain connected to the configured Supabase project.
class AppConfig {
  AppConfig._();

  /// Supabase project URL. A build-time define can override the app default.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: SupabasePublicConfig.url,
  );

  /// Publishable (public) key. A build-time define can override the default.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: SupabasePublicConfig.publishableKey,
  );

  /// رابط قاعدة البيانات للقراءة فقط (Read Replica).
  /// يُمرر عبر --dart-define=SUPABASE_READ_URL=...
  /// إذا ترك فارغًا، تُستخدم القاعدة الأساسية للقراءة والكتابة معًا.
  static const String supabaseReadUrl = String.fromEnvironment(
    'SUPABASE_READ_URL',
    defaultValue: '',
  );

  /// Whether a dedicated Read Replica URL has been provided.
  static bool get hasReadReplica => supabaseReadUrl.isNotEmpty;

  /// Where Supabase should send the user after they follow a password-reset
  /// link. Must be registered under Auth -> URL Configuration in the dashboard,
  /// otherwise the redirect is rejected and no recovery session is created.
  /// Injected with `--dart-define=PASSWORD_RECOVERY_REDIRECT=...`.
  static const String passwordRecoveryRedirect = String.fromEnvironment(
    'PASSWORD_RECOVERY_REDIRECT',
  );

  /// Web OAuth client ID used as the Google Sign-In server client ID on
  /// Android. Supplied via `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`.
  /// Defaults to the project's confirmed Web OAuth client so the value is never
  /// empty at runtime, even when no dart-define is passed.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '496541472556-j23g42irr9r93rmeuo078513nj6skiu7.apps.googleusercontent.com',
  );

  /// Shown if public configuration was intentionally cleared. Never includes
  /// a key value, and speaks the language the customer is reading the app in:
  /// this reaches an `AuthException` the sign-in screen can show.
  static String get missingConfigurationMessage => S.configMissing;

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
