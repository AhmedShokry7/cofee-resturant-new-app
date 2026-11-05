part of 'profile_cubit.dart';

@immutable
class ProfileState {
  const ProfileState({
    this.imageBytes,
    this.avatarPath,
    this.isLoading = true,
    this.isUploading = false,
    this.error,
  });

  /// The avatar image itself, held in memory.
  ///
  /// Either the bytes the customer just picked, while the upload runs, or the
  /// bytes read back from Storage. The avatar is a small private image, so
  /// keeping it in memory renders it instantly and needs no second round trip
  /// on every visit.
  final Uint8List? imageBytes;

  /// Stable Storage path persisted in `identity.profiles.avatar_url`.
  final String? avatarPath;

  final bool isLoading;
  final bool isUploading;

  /// A [ProfilePhotoFailure] name, or null. Kept as a token so the UI can
  /// localise it rather than render an exception string.
  final String? error;

  /// True when there is something to draw.
  bool get hasVisibleImage => imageBytes != null;

  /// [error] as a sentence the customer can act on.
  ///
  /// The state keeps the failure token so the cache, the cubit and the tests
  /// can act on which failure it was; only the screen needs the wording, and
  /// every failure is reported - a photo that did not save is never presented
  /// as one that did.
  String? get errorCopy {
    final failure = error;
    if (failure == null) return null;
    if (failure == ProfilePhotoFailure.unsupportedFormat.name) {
      return S.photoFormatUnsupported;
    }
    if (failure == ProfilePhotoFailure.notSignedIn.name) {
      // The photo belongs to an account, so there is nothing to attach it to
      // without one. This is not a failed save.
      return S.photoSignInRequired;
    }
    if (failure == ProfilePhotoFailure.profileUpdateFailed.name ||
        failure == ProfilePhotoFailure.profileRowMissing.name) {
      return S.photoSaveFailed;
    }
    if (failure == ProfilePhotoFailure.photoLoadFailed.name) {
      return S.photoLoadFailed;
    }
    return S.photoUploadFailed;
  }

  ProfileState copyWith({
    Uint8List? imageBytes,
    String? avatarPath,
    bool? isLoading,
    bool? isUploading,
    String? error,
    bool clearError = false,
    bool clearImage = false,
    bool clearAvatar = false,
  }) => ProfileState(
    imageBytes: clearAvatar || clearImage
        ? null
        : (imageBytes ?? this.imageBytes),
    avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    isLoading: isLoading ?? this.isLoading,
    isUploading: isUploading ?? this.isUploading,
    error: clearError ? null : (error ?? this.error),
  );
}
