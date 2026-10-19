/// Why a profile-photo operation could not be completed.
///
/// The reason is carried as a token so the UI can localise it instead of
/// showing a raw exception string. The message is developer-facing only and is
/// never shown to a customer.
library;

enum ProfilePhotoFailure {
  /// No Supabase session. The photo belongs to an account, so there is nothing
  /// to attach it to.
  notSignedIn,

  /// The picked bytes are not a JPEG, PNG or WebP container.
  unsupportedFormat,

  /// The Storage upload failed.
  uploadFailed,

  /// The upload worked but `identity.profiles.avatar_url` could not be written.
  /// Reported separately from [uploadFailed] because the photo is in Storage
  /// while the profile still points at the old one.
  profileUpdateFailed,

  /// The signed URL could not be created.
  signedUrlFailed,

  /// Reading the saved path or resolving its URL failed for a reason that is not
  /// one of the specific cases above.
  photoLoadFailed,

  /// `identity.profiles` has no row for this auth user, so there is nowhere to
  /// record the path.
  profileRowMissing,
}

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.failure, [this.detail]);

  final ProfilePhotoFailure failure;

  /// Developer-facing context. Never rendered to a customer.
  final String? detail;

  @override
  String toString() =>
      'ProfilePhotoException(${failure.name}${detail == null ? '' : ': $detail'})';
}