part of 'profile_cubit.dart';

@immutable
class ProfileState {
  const ProfileState({
    this.localBytes,
    this.avatarPath,
    this.signedUrl,
    this.signedUrlExpiresAt,
    this.isLoading = true,
    this.isUploading = false,
    this.error,
  });

  /// Bytes of the image the customer just picked.
  ///
  /// Preview only. It is never the source of truth: the saved photo lives in
  /// Storage and [avatarPath] is what survives the session.
  final Uint8List? localBytes;

  /// Stable Storage path persisted in `identity.profiles.avatar_url`.
  final String? avatarPath;

  /// Short-lived displayable URL resolved from [avatarPath].
  final String? signedUrl;

  /// When [signedUrl] stops working. Refreshed before it lapses.
  final DateTime? signedUrlExpiresAt;

  final bool isLoading;
  final bool isUploading;

  /// A [ProfilePhotoFailure] name, or null. Kept as a token so the UI can
  /// localise it rather than render an exception string.
  final String? error;

  /// True when there is something to draw, from either source.
  bool get hasVisibleImage =>
      localBytes != null || (signedUrl?.trim().isNotEmpty ?? false);

  /// True while the signed URL is still usable.
  ///
  /// The margin matters: a URL that lapses while the image is being fetched
  /// fails for a reason the app could have prevented.
  bool get signedUrlIsFresh {
    final expiresAt = signedUrlExpiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(
      expiresAt.subtract(const Duration(minutes: 5)),
    );
  }

  ProfileState copyWith({
    Uint8List? localBytes,
    String? avatarPath,
    String? signedUrl,
    DateTime? signedUrlExpiresAt,
    bool? isLoading,
    bool? isUploading,
    String? error,
    bool clearError = false,
    bool clearLocalBytes = false,
    bool clearAvatar = false,
  }) => ProfileState(
    localBytes: clearLocalBytes ? null : (localBytes ?? this.localBytes),
    avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    signedUrl: clearAvatar ? null : (signedUrl ?? this.signedUrl),
    signedUrlExpiresAt: clearAvatar
        ? null
        : (signedUrlExpiresAt ?? this.signedUrlExpiresAt),
    isLoading: isLoading ?? this.isLoading,
    isUploading: isUploading ?? this.isUploading,
    error: clearError ? null : (error ?? this.error),
  );
}