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
