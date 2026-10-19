import 'package:flutter/foundation.dart';
import 'package:admin_app/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? _client;
  static Future<SupabaseClient?>? _initialising;
  static Object? _initialisationError;

  static bool get isReady => _client != null;

  @visibleForTesting
  static bool debugSignedIn = false;

  @visibleForTesting
  static void debugSetSignedIn(bool value) => debugSignedIn = value;

  static bool get isSignedIn =>
      debugSignedIn || (_client != null && _client!.auth.currentUser != null);

  static bool get isConfigured => AppConfig.isSupabaseConfigured;

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

  static Object? get initialisationError => _initialisationError;

  @visibleForTesting
  static void debugReset() {
    _client = null;
    _initialising = null;
    _initialisationError = null;
    debugSignedIn = false;
  }
}
