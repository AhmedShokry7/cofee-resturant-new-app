import 'dart:typed_data';

import 'package:new_coffee/features/profile/data/model/profile_photo_exception.dart';
import 'package:new_coffee/features/profile/data/repositories/profile_photo_repository.dart';

/// In-memory [ProfilePhotoRepository] for widget tests.
///
/// Stands in for Supabase Storage and the `identity.profiles` row. The stored
/// path survives across cubit instances, which is what lets a test simulate a
/// fresh app session picking up a photo a previous session saved.
class InMemoryProfilePhotoRepository implements ProfilePhotoRepository {
  InMemoryProfilePhotoRepository({this.storedPath});

  /// Path already saved on the "server" before the test starts.
  String? storedPath;

  /// Paths handed out, newest last. One entry per successful upload.
  final List<String> uploadedPaths = [];

  /// When set, [uploadAvatar] throws it.
  Object? uploadError;

  /// When set, [loadAvatarPath] throws it.
  Object? loadError;

  /// When set, [downloadAvatar] throws it.
  Object? downloadError;

  /// Set when the profile row is absent, so the update matches no rows.
  bool profileRowMissing = false;

  int uploadCalls = 0;

  /// Paths [downloadAvatar] was asked for.
  final List<String> downloadedPaths = [];

  @override
  Future<String?> loadAvatarPath() async {
    if (loadError != null) throw loadError!;
    return storedPath;
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    uploadCalls++;
    if (uploadError != null) throw uploadError!;
    if (profileRowMissing) {
      throw const ProfilePhotoException(
        ProfilePhotoFailure.profileRowMissing,
      );
    }
    storedPath = 'uid/avatar.jpg';
    uploadedPaths.add(storedPath!);
    return storedPath!;
  }

  @override
  Future<Uint8List> downloadAvatar(String path) async {
    if (downloadError != null) throw downloadError!;
    downloadedPaths.add(path);
    // A real 1x1 PNG, so a widget test can put it in front of the decoder.
    return Uint8List.fromList(const [
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
  }

  @override
  Future<void> removeAvatar() async {
    storedPath = null;
  }
}
