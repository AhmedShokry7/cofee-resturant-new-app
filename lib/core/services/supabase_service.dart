import 'package:flutter/foundation.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns the single [SupabaseClient] for the process.
///
/// Initialisation is lazy and idempotent: every caller awaits [client] and gets
/// the same instance. When credentials are absent the app stays on the local
/// mock repositories instead of crashing at startup.
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? _client;
  static Future<SupabaseClient?>? _initialising;
  static Object? _initialisationError;

  static bool get isReady => _client != null;

  /// Whether the app should use the live backend.
  static bool get isConfigured => AppConfig.isSupabaseConfigured;

  /// The shared client. Throws [StateError] if Supabase was never configured,
  /// so callers cannot silently fall back to a half-initialised client.
  static SupabaseClient get client {
    final instance = _client;
    if (instance == null) {
      throw StateError(
        'SupabaseService.client was read before initialisation.\n'
        '${AppConfig.missingConfigurationMessage}',
      );
    }
    return instance;
  }

  /// Initialise once. Safe to call from multiple places.
  static Future<SupabaseClient?> init() {
    if (!AppConfig.isSupabaseConfigured) {
      AppConfig.debugLogConfiguration();
      return Future.value(null);
    }
    return _initialising ??= _doInit();
  }

  static Future<SupabaseClient?> _doInit() async {
    try {
      AppConfig.debugLogConfiguration();
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // Publishable key only. It is the current name for the safe-to-ship
        // public role; the older anonKey parameter is deprecated.
        publishableKey: AppConfig.supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
          persistSession: true,
        ),
      );
      _client = Supabase.instance.client;
      _initialisationError = null;
      return _client;
    } catch (error) {
      _initialisationError = error;
      rethrow;
    }
  }

  /// Exposed so the app can surface a real failure instead of hanging on a
  /// future that will never complete.
  static Object? get initialisationError => _initialisationError;

  /// Test hook. Production code never calls this.
  @visibleForTesting
  static void debugReset() {
    _client = null;
    _initialising = null;
    _initialisationError = null;
  }
}