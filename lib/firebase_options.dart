// Firebase configuration for the Flutter app.
//
// The values come from android/app/google-services.json, which the Firebase
// console generated for the Android app whose package name is
// `com.example.new_coffee`. The Android build reads the same file through the
// google-services Gradle plugin, so the native side and the Dart side always
// describe the same Firebase project.
//
// Only the Android client exists so far. Adding another platform means adding
// the app in the Firebase console and running `flutterfire configure`, which
// regenerates this file with an entry per platform.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// The [FirebaseOptions] of the registered Firebase apps.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  /// The options for the platform the app is running on.
  ///
  /// Throws [UnsupportedError] on a platform that has no Firebase app yet,
  /// because guessing a configuration would only hide the problem.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions has no web configuration. Add a web app in '
        'the Firebase console and run `flutterfire configure`.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions has no configuration for $defaultTargetPlatform. '
          'Add the app in the Firebase console and run `flutterfire configure`.',
        );
    }
  }

  /// The Android app `com.example.new_coffee` in the `new-coffee-4d196`
  /// Firebase project.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqwrx4Woa4gu26ryeG3TQ59Kt-_G_GVRk',
    appId: '1:644544428760:android:bd1ecd1816b0952ba035ad',
    messagingSenderId: '644544428760',
    projectId: 'new-coffee-4d196',
    storageBucket: 'new-coffee-4d196.firebasestorage.app',
  );
}
