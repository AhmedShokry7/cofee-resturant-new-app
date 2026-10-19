import 'dart:typed_data';

import 'package:new_coffee/features/profile/data/models/profile_photo_exception.dart';
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

  /// When set, [resolveSignedUrl] throws it.
  Object? signedUrlError;

  /// Set when the profile row is absent, so the update matches no rows.
  bool profileRowMissing = false;

  int uploadCalls = 0;

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
  Future<String> resolveSignedUrl(String path) async {
    if (signedUrlError != null) throw signedUrlError!;
    return 'https://signed.example/$path?token=t';
  }

  @override
  Future<void> removeAvatar() async {
    storedPath = null;
  }
}