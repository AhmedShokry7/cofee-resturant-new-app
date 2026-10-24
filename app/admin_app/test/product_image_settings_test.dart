import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:admin_app/features/catalog/data/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_image_editor.dart';

/// A picture of 40x20 pixels, so the cut is easy to check.
Uint8List _picture() {
  return Uint8List.fromList(
    img.encodePng(
      img.Image(width: 40, height: 20)..clear(img.ColorRgba8(255, 0, 0, 255)),
    ),
  );
}

void main() {
  group('the processing of a picture', () {
    test('the cut takes only the part of the frame', () {
      final result = processImageBytes(
        _picture(),
        crop: const Rect.fromLTWH(10, 0, 20, 20),
      );

      final cut = img.decodePng(result);
      expect(cut, isNotNull);
      expect(cut!.width, 20);
      expect(cut.height, 20);
    });

    test('a turn changes the size of the picture', () {
      final result = processImageBytes(_picture(), rotation: 90);

      final turned = img.decodePng(result);
      expect(turned, isNotNull);
      expect(turned!.width, 20);
      expect(turned.height, 40);
    });

    test('a zoom makes the picture bigger', () {
      final result = processImageBytes(_picture(), scale: 2);

      final zoomed = img.decodePng(result);
      expect(zoomed, isNotNull);
      expect(zoomed!.width, 80);
      expect(zoomed.height, 40);
    });

    test('a picture that cannot be read is refused', () {
      expect(
        () => processImageBytes(Uint8List.fromList(<int>[1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });

    test('the picture without a cut keeps its size', () {
      final result = processImageBytes(_picture());

      final same = img.decodePng(result);
      expect(same, isNotNull);
      expect(same!.width, 40);
      expect(same.height, 20);
    });
  });

  group('the display settings of a picture', () {
    test('a picture without settings keeps the safe default', () {
      final image = AdminProductImage.fromRow(<String, dynamic>{
        'id': 'img-1',
        'product_id': 'p1',
        'image_url': 'https://example.com/one.png',
      });

      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.center);
    });

    test('a picture reads the settings of its row', () {
      final image = AdminProductImage.fromRow(<String, dynamic>{
        'id': 'img-1',
        'product_id': 'p1',
        'image_url': 'https://example.com/one.png',
        'fit': 'contain',
        'alignment': 'topLeft',
      });

      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.topLeft);
    });

    test('the names of the settings survive the round trip', () {
      for (final fit in imageFitOptions) {
        expect(fitFromName(fitName(fit)), fit);
      }
      for (final alignment in imageAlignmentOptions) {
        expect(alignmentFromName(alignmentName(alignment)), alignment);
      }
    });

    test('an unknown name falls back to the safe default', () {
      expect(fitFromName('somethingElse'), BoxFit.cover);
      expect(alignmentFromName('somethingElse'), Alignment.center);
      expect(fitFromName(null), BoxFit.cover);
    });

    test('every way to fill the space has a name the database accepts', () {
      const allowed = <String>{
        'cover',
        'contain',
        'fill',
        'fitWidth',
        'fitHeight',
        'scaleDown',
        'none',
      };

      for (final fit in imageFitOptions) {
        expect(allowed, contains(fitName(fit)));
      }
    });
  });
}
