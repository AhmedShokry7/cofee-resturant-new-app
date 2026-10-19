import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/profile/data/models/profile_photo_exception.dart';
import 'package:new_coffee/features/profile/data/repositories/profile_photo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

part 'profile_state.dart';

/// Owns the customer's profile photo.
///
/// The photo is a [ProfilePhotoRepository] concern; this cubit only decides what
/// is on screen and when. It keeps three sources apart instead of treating them
/// as one image:
///
///   * [ProfileState.localBytes]   the image the customer just picked, so the
///                                avatar updates the instant the sheet closes.
///   * [ProfileState.avatarPath]   the Storage path persisted on the profile.
///                                This is the source of truth.
///   * [ProfileState.signedUrl]    a short-lived displayable URL resolved from
///                                that path, because the bucket is private.
///
/// Everything the customer sees is keyed to the signed-in identity. Signing out
/// or switching accounts drops all three, so one customer's photo can never be
/// rendered for another.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required ProfilePhotoRepository repository})
    : _repository = repository,
      super(const ProfileState()) {
    // Seeded from the same source the repository reads, so restoring the
    // session that is already present is not mistaken for a switch to it.
    _identity = SupabaseService.isReady
        ? SupabaseService.client.auth.currentUser?.id
        : null;
    if (SupabaseService.isReady) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange
          .listen(_onAuthStateChanged);
    }
    load();
  }

  final ProfilePhotoRepository _repository;

  StreamSubscription<AuthState>? _authSubscription;

  /// Identity whose photo is currently in state. Null means guest.
  String? _identity;

  /// Monotonic id of the newest operation. Only the holder may write state, so a
  /// slow upload cannot land after a sign-out cleared the avatar.
  int _generation = 0;

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  /// Reads the persisted path and resolves a URL for it.
  ///
  /// Called on app start, on sign-in, and whenever the page is opened. A guest
  /// or an account without a photo ends with nothing to show, which is the
  /// intended fallback rather than an error.
  Future<void> load() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final path = (await _repository.loadAvatarPath())?.trim();
      if (isClosed || generation != _generation) return;
      if (path == null || path.isEmpty) {
        emit(state.copyWith(clearAvatar: true, isLoading: false));
        return;
      }
      final url = await _repository.resolveSignedUrl(path);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          avatarPath: path,
          signedUrl: url,
          signedUrlExpiresAt: DateTime.now().add(
            ProfilePhotoRepository.signedUrlTtl,
          ),
          isLoading: false,
        ),
      );
    } on ProfilePhotoException catch (error) {
      if (isClosed || generation != _generation) return;
      // Keep the path: the photo may still exist and a later refresh can
      // recover. Drop the URL so a dead one is never rendered.
      emit(
        state.copyWith(
          signedUrl: null,
          signedUrlExpiresAt: null,
          isLoading: false,
          error: error.failure.name,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          signedUrl: null,
          signedUrlExpiresAt: null,
          isLoading: false,
          error: ProfilePhotoFailure.photoLoadFailed.name,
        ),
      );
      addError(error, stackTrace);
    }
  }

  /// Stores a freshly picked image and records it on the profile.
  ///
  /// The picked bytes stay on screen for the whole round trip so the avatar does
  /// not blink back to the old photo. If anything fails the preview is dropped
  /// and whatever was persisted takes over again.
  Future<void> upload(Uint8List bytes) async {
    if (isClosed) return;
    // Rejected locally so an unsupported container never costs a round trip.
    // The repository checks again: the bucket's allowlist is the real limit.
    if (detectProfileImageFormat(bytes) == null) {
      emit(
        state.copyWith(
          clearLocalBytes: true,
          isUploading: false,
          error: ProfilePhotoFailure.unsupportedFormat.name,
        ),
      );
      return;
    }
    final generation = ++_generation;
    emit(state.copyWith(localBytes: bytes, isUploading: true, clearError: true));
    try {
      await _repository.uploadAvatar(bytes);
      if (isClosed || generation != _generation) return;

      // Re-read rather than trusting the returned path: the profile row is what
      // another device will read, so the state must come from the same place.
      final path = await _repository.loadAvatarPath();
      if (isClosed || generation != _generation) return;
      if (path == null) {
        emit(
          ProfileState(
            isLoading: false,
            error: ProfilePhotoFailure.profileUpdateFailed.name,
          ),
        );
        return;
      }
      final url = await _repository.resolveSignedUrl(path);
      if (isClosed || generation != _generation) return;
      emit(
        ProfileState(
          avatarPath: path,
          signedUrl: url,
          signedUrlExpiresAt: DateTime.now().add(
            ProfilePhotoRepository.signedUrlTtl,
          ),
          isLoading: false,
        ),
      );
    } on ProfilePhotoException catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          clearLocalBytes: true,
          isUploading: false,
          error: error.failure.name,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          clearLocalBytes: true,
          isUploading: false,
          error: ProfilePhotoFailure.uploadFailed.name,
        ),
      );
      addError(error, stackTrace);
    }
  }

  /// Drops everything about the current photo. Used on sign-out and on an
  /// account switch, so no cached URL outlives the session that produced it.
  void clear() {
    _generation++;
    emit(const ProfileState());
  }

  /// Refreshes a signed URL that is close to lapsing.
  ///
  /// No-op while the current one is still comfortably valid, so calling it from
  /// `build` costs nothing.
  Future<void> ensureFreshSignedUrl() async {
    if (isClosed) return;
    final path = state.avatarPath;
    if (path == null) return;
    if (state.signedUrlIsFresh) return;
    final generation = ++_generation;
    try {
      final url = await _repository.resolveSignedUrl(path);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          signedUrl: url,
          signedUrlExpiresAt: DateTime.now().add(
            ProfilePhotoRepository.signedUrlTtl,
          ),
          clearError: true,
        ),
      );
    } on ProfilePhotoException catch (error) {
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(error: error.failure.name));
    }
  }

  /// Whether the signed-in customer changed, in which case everything about the
  /// previous customer's photo must be dropped.
  ///
  /// Returns true when this really was a different identity. An ordinary
  /// refresh, a token rotation or a profile edit leaves the photo alone.
  @visibleForTesting
  bool applyIdentityTransition(String? identity) {
    if (identity == _identity) return false;
    _identity = identity;
    // Invalidate anything in flight under the previous identity before it can
    // write the previous customer's URL into this one's state.
    _generation++;
    emit(const ProfileState());
    return true;
  }

  /// `signedIn` brings a different customer's photo and must adopt it.
  /// `signedOut` must drop the signed-in customer's photo entirely.
  /// `passwordRecovery` belongs with `signedIn`: GoTrue emits it instead of
  /// `signedIn` when a recovery link establishes the session. `initialSession` is
  /// ignored because the auth stream replays its latest event to every new
  /// listener and the constructor load already read that same session.
  /// `tokenRefreshed` rotates a token and `userUpdated` edits the profile;
  /// neither can change whose photo this is.
  @visibleForTesting
  bool shouldReloadOnAuthEvent(AuthState auth) =>
      auth.event == AuthChangeEvent.signedIn ||
      auth.event == AuthChangeEvent.passwordRecovery ||
      auth.event == AuthChangeEvent.signedOut;

  @visibleForTesting
  void handleAuthStateChanged(AuthState auth) {
    if (!shouldReloadOnAuthEvent(auth)) return;
    applyIdentityTransition(auth.session?.user.id);
    if (isClosed) return;
    unawaited(load());
  }

  void _onAuthStateChanged(AuthState auth) => handleAuthStateChanged(auth);
}