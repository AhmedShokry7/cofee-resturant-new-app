import 'dart:io';

import 'package:admin_app/core/startup/preferences_recovery_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backs up and repairs a zero-filled Windows preferences file', () async {
    final directory = await Directory.systemTemp.createTemp('admin-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}shared_preferences.json',
    );
    final damaged = List<int>.filled(2557, 0);
    await file.writeAsBytes(damaged);

    expect(await repairZeroFilledPreferencesFile(file), isTrue);
    expect(await file.readAsString(), '{}');
    final backups = directory.listSync().whereType<File>().where(
      (candidate) => candidate.path.contains('.corrupt-'),
    );
    expect(backups, hasLength(1));
    expect(await backups.single.readAsBytes(), damaged);
  });

  test('leaves nonzero preferences untouched', () async {
    final directory = await Directory.systemTemp.createTemp('admin-prefs-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}shared_preferences.json',
    );
    await file.writeAsString('{"flutter.admin_app_language":"ar"}');

    expect(await repairZeroFilledPreferencesFile(file), isFalse);
    expect(await file.readAsString(), '{"flutter.admin_app_language":"ar"}');
    expect(directory.listSync().whereType<File>(), hasLength(1));
  });
}
