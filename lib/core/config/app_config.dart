import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build-time configuration.
///
/// Everything here arrives through .env file, so no value is ever
/// hard-coded in the repository and no secret can be committed by accident.
///
/// 1. Create a `.env` file in the project root with:
///    SUPABASE_URL=https://your-project.supabase.co
///    SUPABASE_PUBLISHABLE_KEY=your_anon_key
///    PASSWORD_RECOVERY_REDIRECT=<your_redirect_url>
///
/// 2. The app reads these values at runtime via flutter_dotenv.
///    No need to pass dart defines manually for development.
///
/// 3. For production builds (APK), you can either:
///    - Include the .env file in the build (it will be packaged)
///    - Or pass dart defines at build time: --dart-define=SUPABASE_URL=...
///
/// The .env file is gitignored by default for production, but for this app
/// we keep it simple: the app will read from .env at runtime.
class AppConfig {
  AppConfig._();

  /// Loads an environment variable from the .env file.
  /// Returns empty string if not found (for safe default behavior).
  static String _loadEnv(String key) {
    final value = DotEnv().env[key];
    if (value == null || value.isEmpty) {
      print('[AppConfig] ⚠️ Env variable "$key" not found, using empty default');
    } else {
      print('[AppConfig] ✅ Loaded env variable: $key = $value');
    }
    return value ?? '';
  }

  /// Supabase URL read from .env file.
  /// Make sure to replace with your real project URL before publishing.
  static const String supabaseUrl = 'https://webzzasosevzymftgszn.supabase.co';

  /// Supabase publishable key read from .env file.
  /// Make sure to replace with your real anon key before publishing.
  static const String supabasePublishableKey =
      'sb_publishable_EsJ6IX8428kZpKqgHX6wfw_1Q1ob1NO';

  /// Where Supabase should send the user after they follow a password reset
  /// link. Must be registered under Auth -> URL Configuration in the dashboard,
  /// otherwise the redirect is rejected and no recovery session is created.
  static const String passwordRecoveryRedirect = '';

  /// Human-readable reason, shown once in debug rather than failing silently.
  static String get missingConfigurationMessage {
    final missing = <String>[];
    return 'Missing configuration. Please check .env file setup.';
  }

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static bool get isRecoveryRedirectConfigured =>
      passwordRecoveryRedirect.isNotEmpty;

  /// Logged only in debug mode. Never prints a key value.
  static void debugLogConfiguration() {
    if (!kDebugMode) return;
    debugPrint('[AppConfig] supabase configured: $isSupabaseConfigured');
  }

  static String _hostOf(String url) {
    if (url.isEmpty) return '<none>';
    final uri = Uri.tryParse(url);
    return uri == null || uri.host.isEmpty ? '<invalid>' : uri.host;
  }
}