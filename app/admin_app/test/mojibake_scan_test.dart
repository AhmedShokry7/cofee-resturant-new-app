import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A repeatable regression check for common mojibake patterns in the source
/// tree of the admin app.
///
/// The check scans every `.dart` file under `lib/` for:
///   - the replacement character U+FFFD
///   - box-drawing characters (U+2500..U+257F) that appear when UTF-8 is
///     decoded as Windows-1252 and re-encoded
///   - the common mojibake sequences `ط·` followed by `ط·` or `ط¸` (Arabic
///     text that was decoded as Latin-1)
///
/// It reports the file and line number of every hit so a regression is easy
/// to locate. The check does not fail on legitimate Unicode characters such
/// as `آ°`, `أ—`, `â€¢`, Arabic letters, or emoji.
void main() {
  test('no mojibake in the admin app source tree', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final content = entity.readAsStringSync(encoding: utf8);
      final lines = content.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Replacement character.
        if (line.contains('\uFFFD')) {
          violations.add(
            '${entity.path}:${i + 1}: U+FFFD replacement character',
          );
        }
        // Box-drawing characters from Latin-1 mis-decode.
        for (final ch in line.runes) {
          if (ch >= 0x2500 && ch <= 0x257F) {
            violations.add(
              '${entity.path}:${i + 1}: box-drawing U+${ch.toRadixString(16)}',
            );
            break;
          }
        }
        // Common Arabic mojibake: "ط·" followed by another "ط·" or "ط¸".
        if (line.contains('\u0637\u0637') || line.contains('\u0637\u0638')) {
          violations.add(
            '${entity.path}:${i + 1}: Arabic mojibake (ط· followed by ط·/ط¸)',
          );
        }
      }
    }

    if (violations.isNotEmpty) {
      fail(
        'Mojibake found in ${violations.length} location(s):\n'
        '${violations.join('\n')}',
      );
    }
  });
}
