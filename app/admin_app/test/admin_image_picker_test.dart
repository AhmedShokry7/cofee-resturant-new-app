import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/admin_image_bytes.dart';
import 'package:admin_app/core/services/admin_image_picker.dart';

/// A file of the device, as the picker hands it over.
Future<XFile> _write(String name, List<int> bytes, {String? mime}) async {
  final directory = await Directory.systemTemp.createTemp('admin_picker');
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes);
  return XFile(file.path, mimeType: mime);
}

void main() {
  test('the type of a picture comes from the name of its file', () {
    expect(adminImageContentTypeOf('photo.PNG', null), 'image/png');
    expect(adminImageContentTypeOf('photo.webp', null), 'image/webp');
    expect(adminImageContentTypeOf('photo.jpeg', null), 'image/jpeg');
    expect(adminImageContentTypeOf('photo.jpg', null), 'image/jpeg');
  });

  test('a name that says nothing leaves the device to speak', () {
    expect(adminImageContentTypeOf('photo', 'image/webp'), 'image/webp');
    expect(adminImageContentTypeOf('photo', null), 'image/jpeg');
  });

  test('a picked file becomes the source of a picture', () async {
    final source = await adminImageSourceOf(
      await _write('coffee.png', <int>[1, 2, 3], mime: 'image/png'),
    );

    expect(source.isLink, isFalse);
    expect(source.bytes, Uint8List.fromList(<int>[1, 2, 3]));
    expect(source.fileName, 'coffee.png');
    expect(source.contentType, 'image/png');
  });

  test('the bytes decide the type when the name lies', () {
    // The browser re-encodes a picture it shrinks and keeps the name of the
    // original file, so a file named .bmp can hold PNG bytes.
    final pngBytes = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47]);
    expect(adminImageSniffedType(pngBytes), 'image/png');
    expect(
      adminImageSniffedType(Uint8List.fromList(<int>[0xff, 0xd8, 0x00, 0x10])),
      'image/jpeg',
    );
    expect(adminImageSniffedType(Uint8List.fromList(<int>[1, 2])), isNull);
    expect(adminImageContentTypeOf('logo.bmp', null), isNot('image/png'));
  });

  test('a picture the browser left as a big PNG is shrunk to a JPEG', () {
    // A flat PNG encodes small, so the shrink is checked on its output: it
    // must be a JPEG the bucket accepts, not the bytes it was handed.
    final picture = img.Image(width: 64, height: 64)
      ..setPixel(0, 0, img.ColorRgb8(10, 200, 40));
    final shrunk = adminImageShrinkToJpeg(
      Uint8List.fromList(img.encodePng(picture)),
      85,
    );

    expect(shrunk, isNotNull);
    expect(adminImageSniffedType(shrunk!), 'image/jpeg');
  });

  test('the file of a shrunk picture is named for what it holds', () {
    expect(adminImageJpegName('photo.png'), 'photo.jpg');
    expect(adminImageJpegName('photo'), 'photo.jpg');
    expect(adminImageJpegName('my.coffee.jpeg'), 'my.coffee.jpg');
  });

  test('a file with nothing in it is refused', () async {
    await expectLater(
      adminImageSourceOf(await _write('empty.jpg', <int>[])),
      throwsA(
        isA<AdminProductException>().having(
          (e) => e.message,
          'message',
          S.imageIsEmpty,
        ),
      ),
    );
  });

  test('a picture too big to shrink is refused', () async {
    await expectLater(
      adminImageSourceOf(
        await _write(
          'huge.jpg',
          List<int>.filled(adminImageMaxBytes + 1, 7),
          mime: 'image/jpeg',
        ),
      ),
      throwsA(
        isA<AdminProductException>().having(
          (e) => e.message,
          'message',
          S.imageTooLarge,
        ),
      ),
    );
  });

  test('closing the picker gives nothing, a file gives its source', () async {
    expect(await pickAdminImage(pickFile: () async => null), isNull);

    final source = await pickAdminImage(
      pickFile: () => _write('latte.jpg', <int>[4, 5], mime: 'image/jpeg'),
    );
    expect(source?.fileName, 'latte.jpg');
    expect(source?.contentType, 'image/jpeg');
  });
}
