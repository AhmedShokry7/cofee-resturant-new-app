import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
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

  test('a file the bucket would refuse is said so before it is read', () async {
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
