import 'dart:typed_data';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/profile/data/model/profile_photo_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, FileOptions;

/// Container formats the avatars bucket accepts.
///
/// The bucket's `allowed_mime_types` is the matching allowlist, so the two must
/// be changed together.
enum ProfileImageFormat {
  jpeg('jpg', 'image/jpeg'),
  png('png', 'image/png'),
  webp('webp', 'image/webp');

  const ProfileImageFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

/// Reads the container format from the leading bytes.
///
/// The file name the picker hands back is not trusted: it is chosen by the
/// source app and says nothing reliable about the actual bytes. Magic numbers
/// do.
ProfileImageFormat? detectProfileImageFormat(Uint8List bytes) {
  bool matches(int offset, List<int> signature) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (matches(0, const [0xFF, 0xD8, 0xFF])) return ProfileImageFormat.jpeg;
  if (matches(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return ProfileImageFormat.png;
  }
  // RIFF....WEBP
  if (matches(0, const [0x52, 0x49, 0x46, 0x46]) &&
      matches(8, const [0x57, 0x45, 0x42, 0x50])) {
    return ProfileImageFormat.webp;
  }
  return null;
}

/// Persistence for the customer's profile photo.
abstract class ProfilePhotoRepository {
  /// Private bucket. Never made public: a public bucket serves every avatar to
  /// anyone holding the object path.
  static const String bucket = 'avatars';

  /// Path of the saved photo, or null when none is saved.
  ///
  /// Returns the Storage path, never a URL.
  Future<String?> loadAvatarPath();

  /// Stores [bytes] under the current user's folder and records the path.
  ///
  /// Returns the persisted path.
  Future<String> uploadAvatar(Uint8List bytes);

  /// Reads the stored photo back as image bytes.
  ///
  /// The bucket is private, so the bytes are fetched with the caller's own
  /// session rather than through a signed URL. A signed URL would have to be
  /// minted first, would expire, and would change on every refresh, which
  /// defeats every image cache in the app.
  Future<Uint8List> downloadAvatar(String path);

  /// Deletes the stored photo and clears the profile's path.
  Future<void> removeAvatar();
}

class SupabaseProfilePhotoRepository implements ProfilePhotoRepository {
  SupabaseProfilePhotoRepository([SupabaseClient? client])
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// The account the photo belongs to.
  ///
  /// Read from the live session rather than from an argument: the server decides
  /// who the caller is, and the Storage policies are keyed on the same
  /// `auth.uid()`.
  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw const ProfilePhotoException(ProfilePhotoFailure.notSignedIn);
    }
    return id;
  }

  @override
  Future<String?> loadAvatarPath() async {
    final id = _uid;
    final row = await _client
        .from('profiles')
        .select('avatar_url')
        .eq('id', id)
        .maybeSingle();
    final path = row?['avatar_url']?.toString();
    if (path == null || path.trim().isEmpty) return null;
    return path.trim();
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    final id = _uid;
    final format = detectProfileImageFormat(bytes);
    if (format == null) {
      throw const ProfilePhotoException(ProfilePhotoFailure.unsupportedFormat);
    }

    // A new object path makes cached avatars on other devices self-invalidating
    // when the customer replaces their photo.
    final previousPath = await loadAvatarPath();
    final path =
        '$id/avatar_${DateTime.now().microsecondsSinceEpoch}.${format.extension}';

    try {
      await _client.storage
          .from(ProfilePhotoRepository.bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: format.mimeType,
              // Each upload has a versioned object path to invalidate local caches.
              upsert: false,
            ),
          );
    } catch (error) {
      throw ProfilePhotoException(
        ProfilePhotoFailure.uploadFailed,
        error.toString(),
      );
    }

    await _writePath(path);
    // The profile now points at the new object. Remove the previous object only
    // after that write succeeds, so a failed profile update keeps the old photo.
    if (previousPath != null && previousPath != path) {
      try {
        await _client.storage.from(ProfilePhotoRepository.bucket).remove([
          previousPath,
        ]);
      } catch (_) {
        // Cleanup only. The profile already points at the new photo.
      }
    }

    return path;
  }

  @override
  Future<Uint8List> downloadAvatar(String path) async {
    if (path.trim().isEmpty) {
      throw const ProfilePhotoException(ProfilePhotoFailure.photoLoadFailed);
    }
    try {
      // The caller's own session authorises the read: the bucket is private
      // and the policies are keyed on the same `auth.uid()` the object path is.
      return await _client.storage
          .from(ProfilePhotoRepository.bucket)
          .download(path);
    } catch (error) {
      throw ProfilePhotoException(
        ProfilePhotoFailure.photoLoadFailed,
        error.toString(),
      );
    }
  }

  @override
  Future<void> removeAvatar() async {
    final path = await loadAvatarPath();
    if (path != null) {
      try {
        await _client.storage.from(ProfilePhotoRepository.bucket).remove([
          path,
        ]);
      } catch (_) {
        // The profile column is cleared either way; a stale object is invisible
        // because nothing points at it.
      }
    }
    await _writePath(null);
  }

  /// Records the path on the caller's own profile row.
  ///
  /// The row is read back, because an update that matched zero rows looks
  /// exactly like a success from the client's point of view. RLS can reject it
  /// and an older account can have no profile row at all; both must surface.
  Future<void> _writePath(String? path) async {
    final id = _uid;
    try {
      final updated = await _client
          .from('profiles')
          .update(<String, dynamic>{
            'avatar_url': path,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .select('avatar_url')
          .maybeSingle();
      if (updated == null) {
        throw const ProfilePhotoException(
          ProfilePhotoFailure.profileRowMissing,
        );
      }
      // RLS and the write can disagree only in theory, but a saved photo that
      // the profile does not point at is exactly the bug this guards.
      final stored = updated['avatar_url']?.toString();
      if (stored != path) {
        throw const ProfilePhotoException(
          ProfilePhotoFailure.profileUpdateFailed,
        );
      }
    } on ProfilePhotoException {
      rethrow;
    } catch (error) {
      throw ProfilePhotoException(
        ProfilePhotoFailure.profileUpdateFailed,
        error.toString(),
      );
    }
  }
}
