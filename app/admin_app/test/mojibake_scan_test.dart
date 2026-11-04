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
///   - an Arabic mis-decode run: the Latin-1 shapes of a UTF-8 Arabic lead
///     byte (`Ø` `Ù` `Ú` `Û`, i.e. 0xD8..0xDB) followed by the shape of its
///     continuation byte. `العربية` broken that way reads `Ø§Ù„Ø¹Ø¨...`.
///
/// It reports the file and line number of every hit so a regression is easy
/// to locate. The Arabic rule looks for the mis-decode artifact itself, not
/// for Arabic letters: `مخطط` and `خطط` are real words the app builds with,
/// while `Ø§` never belongs in Arabic text.
bool _hasArabicMojibake(String line) {
  const leadBytes = <int>[0x00D8, 0x00D9, 0x00DA, 0x00DB];
  // Windows-1252 renders 0x80..0x9F as these, not as C1 controls.
  const cp1252Tails = <int>[
    0x0152,
    0x0153,
    0x0160,
    0x0161,
    0x0178,
    0x017D,
    0x017E,
    0x0192,
    0x02C6,
    0x02DC,
    0x20AC,
    0x2122,
  ];
  final units = line.runes.toList();
  for (var i = 0; i + 1 < units.length; i++) {
    if (!leadBytes.contains(units[i])) continue;
    final tail = units[i + 1];
    final isTail =
        (tail >= 0x0080 && tail <= 0x00FF) ||
        (tail >= 0x2000 && tail <= 0x206F) ||
        cp1252Tails.contains(tail);
    if (isTail) return true;
  }
  return false;
}

void main() {
  test('the Arabic mis-decode rule catches mojibake and spares real words', () {
    // The artifact this guard exists for: UTF-8 Arabic read as Latin-1.
    expect(_hasArabicMojibake(latin1.decode(utf8.encode('العربية'))), isTrue);
    expect(_hasArabicMojibake('Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©'), isTrue);
    // The words the previous rule flagged although they are correct Arabic.
    expect(_hasArabicMojibake('نسخة المخطط لا يطابقها هذا البناء'), isFalse);
    expect(_hasArabicMojibake('خطط اللوحة كلها'), isFalse);
    expect(_hasArabicMojibake('لا face بالشجرة'), isFalse);
  });

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
        // Arabic bytes surfaced through a Latin-1 decoding.
        if (_hasArabicMojibake(line)) {
          violations.add('${entity.path}:${i + 1}: Arabic mojibake run');
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
