// Profile photo persistence and account isolation.
//
// Before the avatar repository existed, a picked photo was only a Uint8List in
// the cubit: gone on restart, invisible on a second device. These tests pin the
// three states that fix depends on — the picked bytes, the persisted Storage
// path, and the short-lived signed URL — and the rule that none of them may
// survive an account change.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/profile/data/models/profile_photo_exception.dart';
import 'package:new_coffee/features/profile/data/repositories/profile_photo_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/profile/profile_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/profile_avatar.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;
import 'support/in_memory_profile_photo_repository.dart';

/// Minimal JPEG magic number; the fake repository never decodes the bytes.
Uint8List jpegBytes([int length = 32]) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(length, 0x01)]);

/// A real 1x1 PNG.
///
/// The widget tests put these bytes in front of Flutter's image decoder, so
/// unlike [jpegBytes] they have to be a genuinely decodable image.
Uint8List pngBytes() => Uint8List.fromList(const [
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

/// Lets the fake repository's promises be released one at a time.
Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('image format detection', () {
    test('recognises the formats the bucket allows', () {
      expect(
        detectProfileImageFormat(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        ProfileImageFormat.jpeg,
      );
      expect(
        detectProfileImageFormat(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        ProfileImageFormat.png,
      );
      expect(
        detectProfileImageFormat(
          Uint8List.fromList([
            0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0,
            0x57, 0x45, 0x42, 0x50,
          ]),
        ),
        ProfileImageFormat.webp,
      );
    });

    test('rejects a container the bucket does not allow', () {
      // GIF, and a truncated JPEG.
      expect(
        detectProfileImageFormat(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
        ),
        isNull,
      );
      expect(detectProfileImageFormat(Uint8List.fromList([0xFF, 0xD8])), isNull);
      expect(detectProfileImageFormat(Uint8List(0)), isNull);
    });

    test('the allowed list matches the bucket mime types', () {
      final mimes =
          ProfileImageFormat.values.map((f) => f.mimeType).toSet().toList()
            ..sort();
      expect(mimes, ['image/jpeg', 'image/png', 'image/webp']);
    });
  });

  group('loading the saved photo', () {
    test('a fresh session picks up the persisted path and resolves a URL', () async {
      // The repository holds what a previous session already saved. Creating a
      // new cubit is exactly what happens on another device after sign-in.
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/avatar.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.avatarPath, 'uid/avatar.jpg');
      expect(cubit.state.signedUrl, contains('uid/avatar.jpg'));
      expect(cubit.state.signedUrlExpiresAt, isNotNull);
      expect(cubit.state.hasVisibleImage, isTrue);
      expect(cubit.state.error, isNull);
    });

    test('no saved photo leaves the existing fallback in place', () async {
      final repository = InMemoryProfilePhotoRepository();
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.avatarPath, isNull);
      expect(cubit.state.signedUrl, isNull);
      expect(cubit.state.hasVisibleImage, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.isLoading, isFalse);
    });

    test('a NULL avatar_url column is treated as no photo, not an error', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: '   ');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.avatarPath, isNull);
      expect(cubit.state.error, isNull);
    });

    test('a missing profile row is reported, not silently treated as empty', () async {
      final repository = InMemoryProfilePhotoRepository()
        ..loadError = const ProfilePhotoException(
          ProfilePhotoFailure.profileRowMissing,
        );
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.error, ProfilePhotoFailure.profileRowMissing.name);
      expect(cubit.state.isLoading, isFalse);
    });
  });

  group('uploading', () {
    test('keeps the picked image visible, then swaps to the persisted path', () async {
      final repository = InMemoryProfilePhotoRepository();
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      final upload = cubit.upload(jpegBytes());
      // Mid-flight: the customer must still see what they just chose.
      expect(cubit.state.localBytes, isNotNull);
      expect(cubit.state.isUploading, isTrue);

      await upload;
      expect(repository.uploadedPaths, ['uid/avatar.jpg']);
      expect(cubit.state.avatarPath, 'uid/avatar.jpg');
      expect(cubit.state.signedUrl, isNotNull);
      // The preview hands over to the server record.
      expect(cubit.state.localBytes, isNull);
      expect(cubit.state.isUploading, isFalse);
      expect(cubit.state.error, isNull);
    });

    test('an upload failure keeps the previously saved photo', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/old.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();
      expect(cubit.state.avatarPath, 'uid/old.jpg');

      repository.uploadError = const ProfilePhotoException(
        ProfilePhotoFailure.uploadFailed,
      );
      await cubit.upload(jpegBytes());

      expect(cubit.state.error, ProfilePhotoFailure.uploadFailed.name);
      expect(cubit.state.localBytes, isNull);
      expect(cubit.state.isUploading, isFalse);
      expect(cubit.state.avatarPath, 'uid/old.jpg');
    });

    test('an unsupported format never reaches Storage', () async {
      final repository = InMemoryProfilePhotoRepository();
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      await cubit.upload(Uint8List.fromList([0x47, 0x49, 0x46, 0x38]));

      expect(repository.uploadCalls, 0);
      expect(cubit.state.error, ProfilePhotoFailure.unsupportedFormat.name);
      expect(cubit.state.isUploading, isFalse);
      expect(cubit.state.hasVisibleImage, isFalse);
    });

    test('a failed profile update is reported instead of claiming success', () async {
      final repository = InMemoryProfilePhotoRepository()
        ..profileRowMissing = true;
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      await cubit.upload(jpegBytes());

      // The photo cannot be shown on another device, so it must not be reported
      // as saved.
      expect(cubit.state.avatarPath, isNull);
      expect(cubit.state.hasVisibleImage, isFalse);
      expect(cubit.state.isUploading, isFalse);
      expect(
        cubit.state.error,
        anyOf(
          ProfilePhotoFailure.profileRowMissing.name,
          ProfilePhotoFailure.profileUpdateFailed.name,
        ),
      );
    });
  });

  group('signed url lifetime', () {
    test('a fresh URL is not re-resolved', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/avatar.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      expect(cubit.state.signedUrlIsFresh, isTrue);
      final url = cubit.state.signedUrl;
      await cubit.ensureFreshSignedUrl();
      await settle();

      expect(cubit.state.signedUrl, url);
    });

    test('an expired URL is refreshed', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/avatar.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      // Age the URL past its refresh margin.
      cubit.emit(
        ProfileState(
          avatarPath: 'uid/avatar.jpg',
          signedUrl: 'https://signed.example/stale',
          signedUrlExpiresAt: DateTime.now().add(const Duration(seconds: 10)),
          isLoading: false,
        ),
      );
      expect(cubit.state.signedUrlIsFresh, isFalse);

      await cubit.ensureFreshSignedUrl();
      await settle();

      expect(cubit.state.signedUrl, contains('uid/avatar.jpg'));
      expect(cubit.state.signedUrlIsFresh, isTrue);
    });

    test('a failed refresh keeps the path and surfaces the error', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/avatar.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      repository.signedUrlError = const ProfilePhotoException(
        ProfilePhotoFailure.signedUrlFailed,
      );
      cubit.emit(
        ProfileState(
          avatarPath: 'uid/avatar.jpg',
          signedUrlExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          isLoading: false,
        ),
      );

      await cubit.ensureFreshSignedUrl();
      await settle();

      expect(cubit.state.error, ProfilePhotoFailure.signedUrlFailed.name);
      expect(cubit.state.avatarPath, 'uid/avatar.jpg');
    });
  });

  group('account isolation', () {
    test('clearing drops every trace of the previous customer', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/avatar.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();
      expect(cubit.state.hasVisibleImage, isTrue);

      cubit.clear();

      expect(cubit.state.avatarPath, isNull);
      expect(cubit.state.signedUrl, isNull);
      expect(cubit.state.localBytes, isNull);
      expect(cubit.state.hasVisibleImage, isFalse);
    });

    test('switching accounts never reuses the previous photo', () async {
      final repository = InMemoryProfilePhotoRepository(storedPath: 'uid/avatar.jpg');
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      // A guest session is what the cubit starts as, so that is not a switch.
      expect(cubit.applyIdentityTransition(null), isFalse);

      expect(cubit.applyIdentityTransition('user-a'), isTrue);
      expect(cubit.state.avatarPath, isNull);
      expect(cubit.state.signedUrl, isNull);

      // Re-stating the same identity is a refresh, not a switch.
      expect(cubit.applyIdentityTransition('user-a'), isFalse);

      // Signing out is a transition too.
      expect(cubit.applyIdentityTransition(null), isTrue);
      expect(cubit.state.hasVisibleImage, isFalse);
    });

    test('an upload in flight when the account changes is discarded', () async {
      final repository = _GatedProfilePhotoRepository();
      final cubit = ProfileCubit(repository: repository);
      addTearDown(cubit.close);
      await settle();

      // The restored session, exactly as on a real start-up.
      cubit.applyIdentityTransition('user-a');
      await settle();

      final upload = cubit.upload(jpegBytes());
      await settle();
      expect(cubit.state.localBytes, isNotNull);

      // The customer signs out before the upload comes back.
      expect(cubit.applyIdentityTransition(null), isTrue);
      repository.release();
      await upload;
      await settle();

      expect(
        cubit.state.hasVisibleImage,
        isFalse,
        reason: 'a URL minted for the previous account must never be rendered',
      );
    });

    test('only session-changing auth events trigger a reload', () {
      final cubit = ProfileCubit(repository: InMemoryProfilePhotoRepository());
      addTearDown(cubit.close);

      AuthState state(AuthChangeEvent event) => AuthState(event, null);

      expect(cubit.shouldReloadOnAuthEvent(state(AuthChangeEvent.signedIn)), isTrue);
      expect(
        cubit.shouldReloadOnAuthEvent(state(AuthChangeEvent.passwordRecovery)),
        isTrue,
      );
      expect(
        cubit.shouldReloadOnAuthEvent(state(AuthChangeEvent.signedOut)),
        isTrue,
      );
      expect(
        cubit.shouldReloadOnAuthEvent(state(AuthChangeEvent.tokenRefreshed)),
        isFalse,
      );
      expect(
        cubit.shouldReloadOnAuthEvent(state(AuthChangeEvent.userUpdated)),
        isFalse,
      );
      expect(
        cubit.shouldReloadOnAuthEvent(state(AuthChangeEvent.initialSession)),
        isFalse,
      );
    });
  });

  group('ProfileAvatar widget', () {
    Widget host(ProfileState state) => MaterialApp(
      home: Scaffold(
        body: ProfileAvatar(state: state, radius: 24),
      ),
    );

    testWidgets('shows the fallback glyph with no photo', (tester) async {
      await tester.pumpWidget(host(const ProfileState(isLoading: false)));
      await tester.pump();

      expect(find.byType(DbImage), findsNothing);
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('renders the persisted photo through DbImage', (tester) async {
      await tester.pumpWidget(
        host(
          const ProfileState(
            avatarPath: 'uid/avatar.jpg',
            signedUrl: 'https://signed.example/uid/avatar.jpg?token=t',
            isLoading: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DbImage), findsOneWidget);
    });

    testWidgets('shows the picked bytes ahead of the network image', (tester) async {
      await tester.pumpWidget(
        host(
          ProfileState(
            localBytes: pngBytes(),
            avatarPath: 'uid/avatar.jpg',
            signedUrl: 'https://signed.example/uid/avatar.jpg?token=t',
            isUploading: true,
            isLoading: false,
          ),
        ),
      );
      await tester.pump();

      // The preview wins, and the upload scrim does not blank it.
      expect(find.byType(DbImage), findsNothing);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

/// Repository whose upload only completes when the test says so.
class _GatedProfilePhotoRepository extends InMemoryProfilePhotoRepository {
  final Completer<void> _gate = Completer<void>();

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    uploadCalls++;
    await _gate.future;
    storedPath = 'uid/avatar.jpg';
    return storedPath!;
  }

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }
}