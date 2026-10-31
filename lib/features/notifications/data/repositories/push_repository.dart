import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
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

  /// The switches of the customer, as the server holds them.
  Future<NotificationPreferences> preferences();

  /// Writes any subset of the switches and answers with the row the server
  /// kept, so the screen shows what was stored rather than what was asked.
  ///
  /// [pushEnabled] and [emailEnabled] are the two channels; an argument left
  /// null is a switch this write does not touch.
  Future<NotificationPreferences> setPreferences({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
  });
}

class PushRepositoryImpl implements PushRepository {
  const PushRepositoryImpl({SupabaseClient? client}) : _clientOverride = client;

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
    final saved = await setPreferences(pushEnabled: enabled);
    return saved.pushEnabled;
  }

  @override
  Future<NotificationPreferences> preferences() async {
    final client = _requireClient();
    final result = await client.rpc('push_preferences');
    if (result is Map) {
      return NotificationPreferences.fromJson(Db.asMap(result));
    }
    return const NotificationPreferences();
  }

  @override
  Future<NotificationPreferences> setPreferences({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? orderStatus,
    bool? promo,
    bool? loyalty,
    bool? system,
  }) async {
    final client = _requireClient();
    final result = await client.rpc(
      'set_push_preferences',
      params: <String, Object?>{
        'p_push_enabled': ?pushEnabled,
        'p_email_enabled': ?emailEnabled,
        'p_order_status': ?orderStatus,
        'p_promo': ?promo,
        'p_loyalty': ?loyalty,
        'p_system': ?system,
      },
    );
    if (result is Map) {
      return NotificationPreferences.fromJson(Db.asMap(result));
    }
    return const NotificationPreferences();
  }
}
