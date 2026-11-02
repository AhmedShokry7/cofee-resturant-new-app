// The Google Sign-In configuration this repository ships, asserted rather than
// remembered.
//
// Why this exists as a test and not only as a note: a device said
// `code=canceled` while Credential Manager had actually said
// `[16] Account reauth failed`, and the app went silent. The Dart side of that
// is covered in test/auth_google_sign_in_test.dart. What no Dart test could
// catch is the reason the phone refused - Credential Manager could not match
// this package and this signing certificate to an Android OAuth client - so this
// file reads the config the build will ship and fails while it stays wrong.
//
// Evidence measured on 2026-11-01 and 2026-11-02, recorded in
// tool/google_sign_in_setup.json because a test cannot reach the Google Cloud
// console:
//   * emulator-5554, Android 17, one Google account on the device.
//   * GET https://webzzasosevzymftgszn.supabase.co/auth/v1/authorize?provider=google
//     -> 302 accounts.google.com?client_id=496541472556-j23g42irr9r93rmeuo078513nj6skiu7…
//     (re-run it with `dart run tool/check_google_sign_in_config.dart --probe`.)
//     So the provider IS enabled and the app's own GOOGLE_SERVER_CLIENT_ID IS
//     the client Supabase uses.
//   * Google itself accepts that client with the Supabase callback registered
//     on it, and answers `invalid_client` for the same id with one digit
//     changed - the check discriminates, it does not merely load a page.
//   * android/app/google-services.json belongs to the *push* project
//     (new-coffee-4d196 / 644544428760) and nothing reads
//     default_web_client_id, so the two projects being different is correct.
//     A first version of this check demanded they match; that demand was wrong
//     and would have traded a working FCM for a broken sign-in.
//   * ./gradlew :app:printSigningFingerprints prints both certificates and
//     compares them with the record.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_google_sign_in_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final report = checkGoogleSignInConfig(Directory.current);
  final record =
      jsonDecode(File(GoogleSignInSetup.relativePath).readAsStringSync())
          as Map<String, dynamic>;
  // The gate this suite exists for: a human who owns the Google Cloud project
  // has to set it, and nothing here may pretend the local files prove it.
  final confirmedExternally = record['androidClientConfirmed'] == true;

  GoogleSignInFinding findingCalled(String name) => report.findings.firstWhere(
    (finding) => finding.name == name,
    orElse: () => throw StateError(
      'No check named "$name". Findings: '
          '${report.findings.map((finding) => finding.name).toList()}',
    ),
  );

  group('what the configuration files say', () {
    test('the check reads this repository', () {
      expect(report.applicationId, 'com.example.new_coffee');
      expect(report.firebaseProjectNumber, '644544428760');
      expect(report.findings, hasLength(7));
    });

    test('the app asks Credential Manager for the client Supabase uses', () {
      // Measured, not assumed: the authorize redirect carries exactly the id
      // the build passes as serverClientId, so the refusal is not a
      // provider-not-enabled problem and not a wrong-client problem.
      expect(report.serverClientProject, '496541472556');
    });

    test('every local rule passes; only the console gate is open', () {
      // If a second rule ever fails, the run says which - and it is never
      // allowed to hide behind the known-missing registration.
      final failures = report.failures.map((finding) => finding.name).toList();
      expect(
        failures,
        confirmedExternally
            ? isEmpty
            : ['An Android OAuth client is registered for this package and SHA-1'],
        reason: report.findings.map((f) => '${f.name}: ${f.detail}').join('\n'),
      );
    });

    test('the login is not handed the push project\'s client by accident', () {
      // Two different projects are only safe while the client id comes from the
      // dart-define. `default_web_client_id` is the resource generated from
      // google-services.json, and if anything ever reads it, the login would be
      // pointed at the FCM project and every device would refuse it.
      final noResourceClient = findingCalled(
        'The login does not read its client id from generated resources',
      );
      expect(noResourceClient.passed, isTrue, reason: noResourceClient.detail);
    });

    test(
      confirmedExternally
          ? 'an Android OAuth client is registered for this package and SHA-1'
          : 'no Android OAuth client is registered for this package',
      () {
        final gate = findingCalled(
          'An Android OAuth client is registered for this package and SHA-1',
        );
        expect(
          gate.passed,
          confirmedExternally,
          reason: '${gate.detail}\n${gate.fix}',
        );
      },
    );

    test('the record says what the console has to be told', () {
      // The record is the only place the required values are written down, so
      // it has to agree with the files the build actually ships.
      expect(record['packageName'], report.applicationId);
      expect(record['authProjectNumber'], report.serverClientProject);
      expect(
        (record['firebaseProjectForPushOnly'] as Map<String, dynamic>)['projectNumber'],
        report.firebaseProjectNumber,
      );
      expect(
        record['webClientId'],
        report.serverClientId,
        reason: 'the recorded client has to be the one compiled in',
      );
    });

    test('both signing certificates are recorded, and only in public form', () {
      final certificates =
          (record['signingCertificates'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(certificates.map((c) => c['kind']).toSet(), {'debug', 'release'});
      final sha1 = RegExp(r'^([0-9A-F]{2}:){19}[0-9A-F]{2}$');
      for (final certificate in certificates) {
        expect(
          sha1.hasMatch(certificate['sha1'] as String),
          isTrue,
          reason: '${certificate['kind']} SHA-1 is not a fingerprint',
        );
      }
      // A record is not a place for a client secret or a private key.
      expect(
        record.keys.where(
          (key) =>
              key.toLowerCase().contains('secret') ||
              key.toLowerCase().contains('password') ||
              key.toLowerCase().contains('private'),
        ),
        isEmpty,
      );
    });

    test('a rule with nothing to inspect stays not applicable, never failed', () {
      // A missing record used to print "clients without a fingerprint: 0",
      // which reads like a broken count rather than a missing registration.
      for (final finding in report.findings.where((f) => f.passed == null)) {
        expect(
          finding.failed,
          isFalse,
          reason: '${finding.name} is unusable and must not be counted twice',
        );
        expect(
          finding.detail,
          isNotEmpty,
          reason: 'an unusable result has to say why it is unusable',
        );
      }
    });
  });

  group('the fingerprints a registration needs', () {
    test(
      'the gradle task prints them and compares them with the record',
      () {
        // Registering the wrong SHA-1 is the same dead end as registering none,
        // and a renewed keystore changes the answer silently. So the number has
        // to come from the certificate the build actually uses, and be checked
        // against the record the suite trusts.
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(gradle, contains('printSigningFingerprints'));
        expect(
          gradle,
          contains('Debug signing certificate'),
          reason:
              'the debug certificate is what an emulator is handed, so it '
              'has to be printed next to the release one',
        );
        expect(
          gradle,
          contains('google_sign_in_setup.json'),
          reason: 'the printed fingerprints must be checked against the record',
        );
      },
    );
  });
}
