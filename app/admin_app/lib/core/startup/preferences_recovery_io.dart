import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

/// The Windows preferences plugin stores every preference and the Supabase
/// session in one JSON file. A truncated, zero-filled write makes all three
/// initializers fail before the first frame.
Future<void> repairZeroFilledPreferences() async {
  if (!Platform.isWindows) return;

  final supportPath = await PathProviderWindows().getApplicationSupportPath();
  if (supportPath == null) return;

  final file = File(
    '$supportPath${Platform.pathSeparator}shared_preferences.json',
  );
  await repairZeroFilledPreferencesFile(file);
}

@visibleForTesting
Future<bool> repairZeroFilledPreferencesFile(File file) async {
  if (!await file.exists()) return false;

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.any((byte) => byte != 0)) return false;

  // Keep the damaged file for inspection; never overwrite a file that might
  // contain recoverable preferences or an authentication session.
  final backup = File(
    '${file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
  );
  await file.copy(backup.path);
  await file.writeAsString('{}', flush: true);
  debugPrint(
    '[preferences.recovery] Replaced a zero-filled preferences file. '
    'The saved session must be signed in again.',
  );
  return true;
}
