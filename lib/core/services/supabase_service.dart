import 'package:flutter/foundation.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns the single [SupabaseClient] for the process.
///
/// Initialisation is lazy and idempotent: every caller awaits [client] and gets
/// the same instance. Production providers throw a clear error when the
/// backend was never configured instead of serving fabricated data.
class SupabaseService {
  const SupabaseService._();

  static SupabaseClient? _client;
  static Future<SupabaseClient?>? _initialising;
  static Object? _initialisationError;

  static bool get isReady => _client != null;

  /// Test hook for simulating an authenticated session without a live backend.
  @visibleForTesting
  static bool debugSignedIn = false;

  @visibleForTesting
  static void debugSetSignedIn(bool value) => debugSignedIn = value;

  /// Whether the current process has an authenticated customer.
  static bool get isSignedIn =>
      debugSignedIn || (_client != null && _client!.auth.currentUser != null);

  /// Whether the backend is configured.
  static bool get isConfigured => AppConfig.isSupabaseConfigured;

  static bool _passwordRecoverySeen = false;

  /// Whether this process got its session by opening the emailed reset link.
  ///
  /// The reset screen has to be able to tell the two kinds of live session
  /// apart. One that was already on the device proves somebody signed in — not
  /// that they own the mailbox — so letting it set a new password would turn an
  /// unlocked, signed-in phone into a way to take an account over without ever
  /// knowing its password.
  static bool get passwordRecoverySeen => _passwordRecoverySeen;

  /// Records the auth events the app cannot afford to miss.
  ///
  /// Supabase reports `passwordRecovery` once, the moment the link is
  /// processed. The screen that needs to know about it is opened later and
  /// cannot rewind that broadcast stream, so the answer is kept here for the
  /// lifetime of the session.
  static void _watchAuthEvents(SupabaseClient client) {
    client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _passwordRecoverySeen = true;
        return;
      }
      // A new session, or an ended one, retires the proof: the link that
      // authorised the previous session says nothing about this one.
      if (state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.signedOut) {
        _passwordRecoverySeen = false;
      }
    });
  }

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
  ///
  /// A failed attempt is not remembered: the next call tries again. The
  /// alternative — caching the failed future — meant that one dropped
  /// connection at start-up left the app without a backend for its whole
  /// lifetime, and every sign-in then failed with "the service is
  /// unavailable" even after the network came back.
  static Future<SupabaseClient?> init() {
    if (!AppConfig.isSupabaseConfigured) {
      AppConfig.debugLogConfiguration();
      return Future.value(null);
    }
    final pending = _initialising ??= _doInit();
    return pending.whenComplete(() {
      if (_client == null) _initialising = null;
    });
  }

  /// Makes sure a client exists, retrying a failed start-up.
  ///
  /// Called before the first request that needs the backend. A phone that
  /// wakes up on a flaky connection, or an app that was started before the
  /// network came back, recovers by itself instead of showing an error the
  /// customer cannot do anything about.
  static Future<SupabaseClient?> ensureReady({
    int attempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    if (_client != null) return _client;
    if (!AppConfig.isSupabaseConfigured) return null;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final client = await init();
        if (client != null) return client;
        return null;
      } catch (_) {
        // The error stays in [initialisationError] for diagnosis; the next
        // attempt starts from scratch.
      }
      if (attempt < attempts) {
        await Future<void>.delayed(delay * attempt);
      }
    }
    return _client;
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
      _watchAuthEvents(_client!);
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

  @visibleForTesting
  static void debugSetPasswordRecoverySeen(bool value) =>
      _passwordRecoverySeen = value;

  /// Test hook. Production code never calls this.
  @visibleForTesting
  static void debugReset() {
    _client = null;
    _initialising = null;
    _initialisationError = null;
    _passwordRecoverySeen = false;
  }

  /// Test hook for injecting a client that talks to a fake server.
  ///
  /// Production code never calls this: the client is created by [init] and
  /// nowhere else. It exists so a repository that goes through
  /// [SupabaseService.client] can be covered without a live backend.
  @visibleForTesting
  static void debugSetClient(SupabaseClient? client) {
    _client = client;
    _initialising = null;
    _initialisationError = null;
  }
}
