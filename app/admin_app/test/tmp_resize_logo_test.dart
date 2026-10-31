import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// One-off resize of the shipped logo, run with `flutter test` on purpose: it
// uses the same Skia decoder the app uses, at the same quality filter, so the
// result is the picture Flutter would have produced in memory anyway.
Future<void> main() async {
  test('resize logo.png to 1024', () async {
    const path = 'assets/images/logo.png';
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1024,
      targetHeight: 1024,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    expect(data, isNotNull, reason: 'the tester could not encode a PNG');
    final out = File('${Directory.systemTemp.path}/logo_1024.png')
      ..createSync(recursive: true);
    out.writeAsBytesSync(data!.buffer.asUint8List());
    stderr.writeln(
      'wrote ${out.path}: ${out.lengthSync()} bytes from ${bytes.length}',
    );
  });
}
