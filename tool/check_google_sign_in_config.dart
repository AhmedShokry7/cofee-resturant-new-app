// Checks, before a build is trusted, that this app's Google Sign-In setup can
// actually work on a phone.
//
// Every rule here was learned from a device that failed: Credential Manager
// answered `[16] Account reauth failed`, which is what a phone says when it
// cannot match this package and this signing certificate to an Android OAuth
// client. No Dart code can fix that, and no test of Dart code would have caught
// it - so this file reads what the build ships and says which part is wrong.
//
//   dart run tool/check_google_sign_in_config.dart
//
// Exits 0 when nothing local contradicts a working sign-in, 1 when something
// does. test/auth_google_sign_in_configuration_test.dart calls the same
// [checkGoogleSignInConfig] instead of holding a second copy of the rules, so
// the command line and the suite can never disagree.
//
//   dart run tool/check_google_sign_in_config.dart --probe
//
// additionally asks the two public endpoints that own the rest of the answer:
// Supabase, which web client it redirects to, and Google, whether that client
// exists with the Supabase callback registered on it. A probe sends nothing but
// a GET and reads nothing but headers, so it is opt-in - but when it runs, its
// findings count towards the exit code like any other rule.
//
// What no local file can prove is recorded in tool/google_sign_in_setup.json:
// the package name, both certificate fingerprints and the project the Android
// OAuth client has to live in. Until a human who owns that project marks it
// confirmed, one rule stays red on purpose. The alternative - letting the check
// go green while every device still refuses - would train everyone to ignore it.

import 'dart:convert';
import 'dart:io';

/// One line of the report, with the file that has to change to fix it.
///
/// [passed] is null when the rule cannot be evaluated yet because a rule it
/// depends on already failed - reporting that as a failure would state a count
/// of zero that means nothing.
class GoogleSignInFinding {
  const GoogleSignInFinding(this.name, this.passed, this.detail, this.fix);

  const GoogleSignInFinding.notApplicable(this.name, this.detail)
    : passed = null,
      fix = '';

  final String name;
  final bool? passed;
  final String detail;
  final String fix;

  bool get failed => passed == false;
}

/// The recorded answer to the question no file in this repository can ask:
/// what Google Cloud holds for this app.
class GoogleSignInSetup {
  const GoogleSignInSetup({
    required this.exists,
    required this.authProjectNumber,
    required this.packageName,
    required this.pushProjectNumber,
    required this.certificates,
    required this.androidClientConfirmed,
  });

  const GoogleSignInSetup.missing()
    : exists = false,
      authProjectNumber = null,
      packageName = null,
      pushProjectNumber = null,
      certificates = const <Map<String, dynamic>>[],
      androidClientConfirmed = false;

  final bool exists;
  final String? authProjectNumber;
  final String? packageName;
  final String? pushProjectNumber;

  /// `{kind, subject, sha1, sha256}` per signing certificate.
  final List<Map<String, dynamic>> certificates;
  final bool androidClientConfirmed;

  static const String relativePath = 'tool/google_sign_in_setup.json';

  static GoogleSignInSetup read(Directory root) {
    final file = File('${root.path}/$relativePath');
    if (!file.existsSync()) {
      return const GoogleSignInSetup.missing();
    }
    try {
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final push = map['firebaseProjectForPushOnly'];
      return GoogleSignInSetup(
        exists: true,
        authProjectNumber: map['authProjectNumber'] as String?,
        packageName: map['packageName'] as String?,
        pushProjectNumber:
            push is Map<String, dynamic> ? push['projectNumber'] as String? : null,
        certificates:
            (map['signingCertificates'] as List<dynamic>? ?? const <Object>[])
                .cast<Map<String, dynamic>>(),
        androidClientConfirmed: map['androidClientConfirmed'] == true,
      );
    } on Exception {
      return const GoogleSignInSetup.missing();
    }
  }
}

/// Everything the check read and decided.
class GoogleSignInReport {
  const GoogleSignInReport({
    required this.applicationId,
    required this.firebaseProjectId,
    required this.firebaseProjectNumber,
    required this.serverClientId,
    required this.findings,
  });

  final String? applicationId;
  final String firebaseProjectId;
  final String firebaseProjectNumber;

  /// The client the build hands to Credential Manager, or null when no build
  /// would hand one at all.
  final String? serverClientId;
  final List<GoogleSignInFinding> findings;

  /// The Google Cloud project number every OAuth client id is prefixed with.
  String? get serverClientProject => serverClientId?.split('-').first;

  List<GoogleSignInFinding> get failures =>
      findings.where((finding) => finding.failed).toList();
}

Future<void> main(List<String> args) async {
  final root = Directory.current;
  final report = checkGoogleSignInConfig(root);
  stdout.writeln('Google Sign-In configuration check');
  stdout.writeln('  applicationId    : ${report.applicationId}');
  stdout.writeln(
    '  push project     : ${report.firebaseProjectId} '
    '(${report.firebaseProjectNumber})',
  );
  stdout.writeln(
    '  auth project     : ${report.serverClientProject ?? '(none)'}',
  );
  stdout.writeln('  serverClientId   : ${report.serverClientId ?? '(none)'}');
  stdout.writeln('');
  for (final finding in report.findings) {
    stdout.writeln(_describe(finding));
  }

  var probeFindings = const <GoogleSignInFinding>[];
  if (args.contains('--probe') || args.contains('--probe-supabase')) {
    stdout.writeln('');
    stdout.writeln('public endpoints (no key, no token, GET only)');
    probeFindings = await probeGoogleSignInEndpoints(root, report);
    for (final finding in probeFindings) {
      stdout.writeln(_describe(finding));
    }
  }

  stdout.writeln('');
  stdout.writeln(verdictFor(report, probes: probeFindings));

  final failures =
      report.findings.where((finding) => finding.failed).length +
      probeFindings.where((finding) => finding.failed).length;
  if (failures > 0) {
    exitCode = 1;
  }
}

String _describe(GoogleSignInFinding finding) {
  final label = switch (finding.passed) {
    true => '  ok  ',
    false => ' FAIL ',
    null => '  n/a ',
  };
  final buffer = StringBuffer('$label ${finding.name}\n        ${finding.detail}');
  if (finding.failed) {
    buffer.write('\n        fix: ${finding.fix}');
  }
  return buffer.toString();
}

/// The one line a developer reads after the list.
///
/// [probes] are the endpoint findings, when they ran: leaving them out of the
/// count would report "7 of 7 passed" under a `--probe` run that asked nine
/// questions.
String verdictFor(
  GoogleSignInReport report, {
  List<GoogleSignInFinding> probes = const <GoogleSignInFinding>[],
}) {
  final all = <GoogleSignInFinding>[...report.findings, ...probes];
  final broken = all.where((finding) => finding.failed).length;
  if (broken == 0) {
    final notApplicable = all
        .where((finding) => finding.passed == null)
        .length;
    return '${all.length - notApplicable} of ${all.length} checks passed and '
        'the rest do not apply. Nothing this repository holds, and nothing the '
        'public endpoints said, contradicts a working Google sign-in.';
  }
  return '$broken of ${all.length} checks failed: a real device will refuse '
      'this sign-in. Fix the files above before testing again.';
}

/// Reads the files this build would ship and applies every rule.
///
/// [root] is the repository root - the directory `flutter build` is run from.
GoogleSignInReport checkGoogleSignInConfig(Directory root) {
  final findings = <GoogleSignInFinding>[];
  final gradleFile = File('${root.path}/android/app/build.gradle.kts');
  final jsonFile = File('${root.path}/android/app/google-services.json');
  final envFile = File('${root.path}/.env.flutter.json');

  if (!gradleFile.existsSync() || !jsonFile.existsSync()) {
    throw StateError(
      'Cannot check: android/app/build.gradle.kts or '
      'android/app/google-services.json is missing.',
    );
  }

  // The applicationId is what Google binds an Android OAuth client to. A
  // suffix on one build type would need its own registered client.
  final gradleSource = gradleFile.readAsStringSync();
  final applicationId = _firstMatch(
    gradleSource,
    RegExp(r'applicationId\s*=\s*"([^"]+)"'),
  );
  final suffixes = RegExp(r'applicationIdSuffix\s*=\s*"([^"]+)"')
      .allMatches(gradleSource)
      .map((match) => match.group(1))
      .toList();

  final Map<String, dynamic> services;
  try {
    services = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException catch (error) {
    throw StateError('google-services.json is not readable JSON: $error');
  }

  final projectInfo = services['project_info'] as Map<String, dynamic>;
  final projectNumber = projectInfo['project_number'] as String;
  final projectId = projectInfo['project_id'] as String;
  final clients = (services['client'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  final jsonClient = clients.firstWhere(
    (client) =>
        applicationId != null && _packageNameOf(client) == applicationId,
    orElse: () => <String, dynamic>{},
  );

  findings.add(
    GoogleSignInFinding(
      'google-services.json describes this applicationId',
      jsonClient.isNotEmpty,
      'applicationId=$applicationId, packages in file: '
          '${clients.map(_packageNameOf).toList()} - this file is what Cloud '
          'Messaging is configured from, not what Google Sign-In reads',
      'Add the Android app with package name "$applicationId" to Firebase '
          'project $projectId and download a fresh google-services.json.',
    ),
  );

  findings.add(
    GoogleSignInFinding(
      'No build type changes the package name behind the registration',
      suffixes.isEmpty,
      'applicationIdSuffix values: $suffixes',
      'Each suffix is a different package to Google, so each needs its own '
          'Android OAuth client.',
    ),
  );

  final serverClientId = _serverClientId(root, envFile);
  findings.add(
    GoogleSignInFinding(
      'A web OAuth client id reaches the build',
      serverClientId != null &&
          serverClientId.endsWith('.apps.googleusercontent.com') &&
          RegExp(r'^\d{1,20}-').hasMatch(serverClientId),
      'serverClientId=$serverClientId (read from '
          '${envFile.existsSync() ? '.env.flutter.json' : 'the AppConfig '
              'default, because .env.flutter.json is not generated yet'})',
      'GOOGLE_SERVER_CLIENT_ID has to be the OAuth *web* client of the project '
          'Supabase redirects to - the ID token is minted for it. Credential '
          'Manager refuses anything else.',
    ),
  );

  // Two Google Cloud projects are in play and that is deliberate: the Firebase
  // one owns push, the other owns the OAuth clients Supabase uses. The split is
  // only safe while nothing reads the login client out of the resources that
  // the google-services plugin generates. If a dependency ever starts doing
  // that - `default_web_client_id` is how it is spelled - the two projects have
  // to become one, because that resource comes from google-services.json.
  final resourceClientLookups = _grepFor(
    root,
    ['android', 'lib'],
    'default_web_client_id',
  );
  final sameProject =
      serverClientId != null && serverClientId.split('-').first == projectNumber;
  findings.add(
    GoogleSignInFinding(
      'The login does not read its client id from generated resources',
      sameProject || resourceClientLookups.isEmpty,
      sameProject
          ? 'serverClientId and google-services.json are the same project, so '
                'the split below cannot matter'
          : 'files naming default_web_client_id: '
                '${resourceClientLookups.isEmpty ? "none" : resourceClientLookups}',
      'Something asks Android for default_web_client_id, and that resource is '
          'generated from google-services.json - so that project has to own '
          'both the web and the Android OAuth client, or the login will be '
          'handed the push project\'s client.',
    ),
  );

  final setup = GoogleSignInSetup.read(root);
  findings.add(
    GoogleSignInFinding(
      'The recorded projects match the files that ship',
      setup.exists &&
          setup.authProjectNumber == serverClientId?.split('-').first &&
          setup.pushProjectNumber == projectNumber &&
          setup.packageName == applicationId,
      setup.exists
          ? 'record: auth=${setup.authProjectNumber} push=${setup.pushProjectNumber} '
                'package=${setup.packageName}; measured: '
                'auth=${serverClientId?.split('-').first} push=$projectNumber '
                'package=$applicationId'
          : '${GoogleSignInSetup.relativePath} is missing or unreadable',
      'Update ${GoogleSignInSetup.relativePath} to the project the web client '
          'belongs to, the project google-services.json comes from, and the '
          'applicationId the build uses.',
    ),
  );

  final badCertificates = setup.certificates
      .where(
        (certificate) =>
            _firstMatch(
              certificate['sha1'] as String? ?? '',
              RegExp(r'^([0-9A-F]{2}:){19}[0-9A-F]{2}$'),
            ) ==
            null,
      )
      .toList();
  findings.add(
    GoogleSignInFinding(
      'Every signing certificate this build can produce is recorded',
      setup.exists &&
          setup.certificates.isNotEmpty &&
          badCertificates.isEmpty &&
          setup.certificates.length >= 2,
      '${setup.certificates.length} certificates recorded '
          '(${setup.certificates.map((c) => c['kind']).toList()}), '
          'badly formed SHA-1: ${badCertificates.length}',
      'Run ./gradlew :app:printSigningFingerprints and record one entry per '
          'certificate: a debug build and a release build are signed '
          'differently, and each SHA-1 needs its own registration or one of '
          'the two answers [16] Account reauth failed.',
    ),
  );

  // The rule that cannot be satisfied from here, and says so instead of
  // pretending the local files prove it.
  findings.add(
    setup.androidClientConfirmed
        ? GoogleSignInFinding(
            'An Android OAuth client is registered for this package and SHA-1',
            true,
            'confirmed in project ${setup.authProjectNumber} for '
                '${setup.packageName} - prove it on a device, then keep it '
                'confirmed only while the fingerprints still match',
            '',
          )
        : GoogleSignInFinding(
            'An Android OAuth client is registered for this package and SHA-1',
            false,
            'not verifiable from this repository: only the Google console '
                'holds Android OAuth clients, and none is recorded as created',
            'In Google Cloud project ${setup.authProjectNumber} (not the push '
                'project ${setup.pushProjectNumber}), create an OAuth client '
                'of type Android for package "${setup.packageName}" with every '
                'SHA-1 in ${GoogleSignInSetup.relativePath}, then set '
                'androidClientConfirmed to true. '
                './gradlew :app:printSigningFingerprints reprints the values.',
          ),
  );

  return GoogleSignInReport(
    applicationId: applicationId,
    firebaseProjectId: projectId,
    firebaseProjectNumber: projectNumber,
    serverClientId: serverClientId,
    findings: findings,
  );
}

/// Asks the two public endpoints that hold the rest of the answer.
///
/// Supabase answers which web client it sends the phone to; Google answers
/// whether that client exists with this Supabase callback registered on it.
/// Neither needs a key. The Google leg also repeats the request with one digit
/// of the client id changed, because "the page loaded" is only evidence when a
/// broken id provably gets a different answer.
Future<List<GoogleSignInFinding>> probeGoogleSignInEndpoints(
  Directory root,
  GoogleSignInReport report,
) async {
  final envFile = File('${root.path}/.env.flutter.json');
  String? url;
  try {
    final map = jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
    url = map['SUPABASE_URL'] as String?;
  } on Exception {
    url = null;
  }
  final supabaseUrl = url;
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    return const <GoogleSignInFinding>[
      GoogleSignInFinding.notApplicable(
        'Supabase redirects to the web client this build ships',
        'no SUPABASE_URL in .env.flutter.json - run '
            'tools/prepare_flutter_config.ps1 first',
      ),
    ];
  }

  final client = HttpClient()
    ..autoUncompress = false
    ..userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  try {
    // 1. What does Supabase send the browser to?
    final authorizeUri = Uri.parse(
      '$supabaseUrl/auth/v1/authorize?provider=google'
      '&redirect_to=https%3A%2F%2Flocalhost.invalid',
    );
    final supabase = await _head(client, authorizeUri);
    final location = supabase.value;
    if (location == null) {
      return <GoogleSignInFinding>[
        GoogleSignInFinding(
          'Supabase redirects to the web client this build ships',
          false,
          'Supabase answered ${supabase.key} with no redirect',
          'Enable the Google provider in Supabase Auth -> Sign-in / methods, '
              'with the web client id and its secret.',
        ),
      ];
    }
    final google = Uri.parse(location);
    final clientId = google.queryParameters['client_id'];
    final redirectUri = google.queryParameters['redirect_uri'];
    final matchesBuild = clientId != null && clientId == report.serverClientId;
    final findings = <GoogleSignInFinding>[
      GoogleSignInFinding(
        'Supabase redirects to the web client this build ships',
        matchesBuild,
        'supabase -> ${google.host} client_id=$clientId '
            'redirect_uri=$redirectUri; build serverClientId='
            '${report.serverClientId}',
        'The app hands Credential Manager a different client than Supabase '
            'uses. Point GOOGLE_SERVER_CLIENT_ID at the client Supabase '
            'redirects to - that is the one the ID token is minted for.',
      ),
    ];

    // 2. Does Google know that client, with this callback allowed on it?
    if (clientId == null || redirectUri == null) {
      findings.add(
        const GoogleSignInFinding(
          'Google accepts that web client with the Supabase callback allowed',
          false,
          'the Supabase redirect carried no client_id or no redirect_uri',
          'The provider is half-configured: re-enter the Google client id and '
              'secret in the Supabase dashboard.',
        ),
      );
      return findings;
    }
    final consent = await _head(
      client,
      google.replace(
        queryParameters: <String, String>{
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': 'openid profile email',
        },
      ),
    );
    final consentTarget = consent.value ?? '';
    final rejected = Uri.tryParse(consentTarget)?.queryParameters['authError'];
    final control = await _head(
      client,
      google.replace(
        queryParameters: <String, String>{
          // One digit changed: an unregistered client has to answer differently,
          // or the check above proves nothing about this one.
          'client_id': clientId.replaceFirst(RegExp(r'^\d'), '1'),
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': 'openid profile email',
        },
      ),
    );
    final controlError = _authErrorOf(control.value);
    findings.add(
      GoogleSignInFinding(
        'Google accepts that web client with the Supabase callback allowed',
        rejected == null && controlError != null,
        'real client -> ${_firstMatch(consentTarget, RegExp(r'requestPath%3D([^&]{1,40})')) ?? consentTarget} '
            'authError=${rejected ?? 'none'}; one-digit-changed client -> '
            'authError=${controlError ?? 'none'}',
        'Google refused this client id. Either it no longer exists, or the '
            'Supabase callback is not in its Authorized redirect URIs - both '
            'are fixed in Google Cloud project '
            '${report.serverClientProject}, Credentials -> the web client.',
      ),
    );
    return findings;
  } on Exception catch (error) {
    return <GoogleSignInFinding>[
      GoogleSignInFinding.notApplicable(
        'Supabase and Google endpoint probes',
        'could not run (no network?): $error',
      ),
    ];
  } finally {
    client.close(force: true);
  }
}

/// The status and Location header of a GET that must not follow redirects:
/// following them would report the 200 of the Google page as if Supabase had
/// answered it itself.
Future<MapEntry<int, String?>> _head(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri)..followRedirects = false;
  final response = await request.close().timeout(const Duration(seconds: 20));
  final location = response.headers.value(HttpHeaders.locationHeader);
  await response.drain<void>();
  return MapEntry(response.statusCode, location);
}

String? _authErrorOf(String? location) {
  if (location == null) {
    return null;
  }
  final raw = Uri.tryParse(location)?.queryParameters['authError'];
  if (raw == null) {
    return null;
  }
  // Google base64url-encodes a protobuf whose readable part is the error token,
  // so decoding it turns "an error came back" into "which error came back".
  try {
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(raw)));
    return _firstMatch(
      decoded,
      RegExp(
        r'invalid_client|unregistered_client_id|redirect_uri_mismatch|'
        r'invalid_request|access_not_configured|deleted_client|org_internal',
      ),
    ) ??
        'present';
  } on FormatException {
    return 'present';
  }
}

List<String> _grepFor(Directory root, List<String> directories, String needle) {
  final hits = <String>[];
  for (final name in directories) {
    final dir = Directory('${root.path}/$name');
    if (!dir.existsSync()) {
      continue;
    }
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final path = entity.path;
      if (!path.endsWith('.kt') &&
          !path.endsWith('.java') &&
          !path.endsWith('.xml') &&
          !path.endsWith('.dart')) {
        continue;
      }
      try {
        if (path.contains(r'build\') || path.contains('/build/')) {
          continue;
        }
        if (entity.readAsStringSync().contains(needle)) {
          hits.add(path.replaceFirst('${root.path}/', ''));
        }
      } on FileSystemException {
        continue;
      }
    }
  }
  return hits;
}

String? _packageNameOf(Map<String, dynamic> client) {
  final info = client['client_info'] as Map<String, dynamic>?;
  final android = info?['android_client_info'] as Map<String, dynamic>?;
  return android?['package_name'] as String?;
}

String? _firstMatch(String source, RegExp pattern) =>
    pattern.firstMatch(source)?.group(1);

/// Where the build will really read the client id from: the dart-define file
/// the launch configuration uses, then the value compiled into AppConfig.
String? _serverClientId(Directory root, File envFile) {
  if (envFile.existsSync()) {
    try {
      final map =
          jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic>;
      final value = map['GOOGLE_SERVER_CLIENT_ID'] as String?;
      if (value != null && value.isNotEmpty) {
        return value;
      }
    } on FormatException {
      // Fall through: the compiled default is still worth reporting.
    }
  }
  final config = File('${root.path}/lib/core/config/app_config.dart');
  if (!config.existsSync()) {
    return null;
  }
  final block = config.readAsStringSync();
  final start = block.indexOf('googleServerClientId');
  if (start < 0) {
    return null;
  }
  final value = _firstMatch(
    block.substring(start),
    RegExp(r"defaultValue:\s*'([^']*)'"),
  );
  return value == null || value.isEmpty ? null : value;
}
