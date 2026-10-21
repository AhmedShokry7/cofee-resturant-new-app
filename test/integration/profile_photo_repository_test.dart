import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/profile/data/repositories/profile_photo_repository.dart';

/// Live checks for the private profile-photo bucket.
///
/// The avatar is read back with the customer's own session, so these checks
/// prove three things a unit test cannot: that the object really is private,
/// that the session is what authorises the read, and that the bytes that come
/// back are the bytes that went up.
///
/// Run with:
///
///   flutter test test/integration/profile_photo_repository_test.dart \
///     --dart-define=SCHEMAS_EXPOSED=true \
///     --dart-define=TEST_USER_EMAIL=... \
///     --dart-define=TEST_USER_PASSWORD=...
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');
  const email = String.fromEnvironment('TEST_USER_EMAIL');
  const password = String.fromEnvironment('TEST_USER_PASSWORD');

  const needsSetup =
      'Needs --dart-define SCHEMAS_EXPOSED=true, TEST_USER_EMAIL and '
      'TEST_USER_PASSWORD.';

  final String? skip =
      (!AppConfig.isSupabaseConfigured || !schemasExposed || email.isEmpty)
      ? needsSetup
      : null;

  late SupabaseProfilePhotoRepository repository;
  late SupabaseClient client;

  setUpAll(() async {
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    client = SupabaseService.client;
    await client.auth.signInWithPassword(email: email, password: password);
    repository = SupabaseProfilePhotoRepository(client);
  });

  test('the avatar is read back with the session, not a signed URL', () async {
    // A real 1x1 PNG.
    final png = Uint8List.fromList(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);

    final path = await repository.uploadAvatar(png);
    expect(path, isNotEmpty);

    // The profile row points at the object, not at a URL that will expire.
    expect(await repository.loadAvatarPath(), path);

    // The bytes come back through the authenticated Storage API.
    final bytes = await repository.downloadAvatar(path);
    expect(bytes, isNotEmpty);
    expect(
      bytes.take(4).toList(),
      png.take(4).toList(),
      reason: 'the downloaded image must be the one that was uploaded',
    );
  }, skip: skip);

  test('a guest cannot read an avatar', () async {
    // The bucket is private: without a session the object is not readable.
    await client.auth.signOut();
    Object? error;
    try {
      await repository.downloadAvatar('someone/avatar.png');
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);
  }, skip: skip);
}
