import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Thrown when a push operation needs a signed-in customer and there is none.
class PushSignInRequiredException implements Exception {
  const PushSignInRequiredException();

  @override
  String toString() => 'Push needs a signed-in customer.';
}

/// The push part of the backend.
///
/// The FCM token of the device and the switches of the customer live on the
/// server, so a customer who signs in on a second phone receives the
/// notifications on both, and the token of a phone that changes account is
/// moved instead of duplicated.
abstract class PushRepository {
  /// Stores the token of this device for the signed-in customer.
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appVersion,
    String? deviceName,
    String? locale,
  });

  /// Removes the token of this device, so the next person who uses the phone
  /// does not receive the notifications of the previous one.
  Future<bool> unregisterToken(String token);

  /// Turns the push of the customer on or off.
  Future<bool> setPushEnabled(bool enabled);

  /// Whether the customer wants to receive pushes.
  Future<bool> isPushEnabled();
}

class PushRepositoryImpl implements PushRepository {
  const PushRepositoryImpl({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient? get _client =>
      _clientOverride ??
      (SupabaseService.isReady ? SupabaseService.client : null);

  /// The client of a signed-in customer.
  ///
  /// The push rows belong to a customer, so there is nothing to do without a
  /// session. Failing loudly is better than storing a token nobody owns.
  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Push needs a configured Supabase backend.');
    }
    if (client.auth.currentUser == null) {
      throw const PushSignInRequiredException();
    }
    return client;
  }

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    String? appVersion,
    String? deviceName,
    String? locale,
  }) async {
    final client = _requireClient();
    await client.rpc(
      'register_device_token',
      params: {
        'p_platform': platform,
        'p_token': token,
        'p_app_version': appVersion,
        'p_device_name': deviceName,
        'p_locale': locale,
      },
    );
  }

  @override
  Future<bool> unregisterToken(String token) async {
    final client = _requireClient();
    final result = await client.rpc(
      'unregister_device_token',
      params: {'p_token': token},
    );
    return result == true;
  }

  @override
  Future<bool> setPushEnabled(bool enabled) async {
    final client = _requireClient();
    final result = await client.rpc(
      'set_push_preferences',
      params: {'p_push_enabled': enabled},
    );
    if (result is Map<String, dynamic>) {
      return result['push_enabled'] == true;
    }
    return enabled;
  }

  @override
  Future<bool> isPushEnabled() async {
    final client = _requireClient();
    final result = await client.rpc('push_preferences');
    if (result is Map<String, dynamic>) {
      return result['push_enabled'] == true;
    }
    return false;
  }
}
