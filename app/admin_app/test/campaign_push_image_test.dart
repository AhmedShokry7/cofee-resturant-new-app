import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/notifications/data/campaign_push_image.dart';

Uint8List _bytesOf(int length) => Uint8List(length)..fillRange(0, length, 7);

Future<CampaignPushImage> _fit(
  int length, {
  Future<Uint8List?> Function(Uint8List)? shrink,
}) => campaignPushImageOf(
  bytes: _bytesOf(length),
  fileName: 'offer.png',
  contentType: 'image/png',
  shrink: shrink,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  test('the FCM ceiling is the one Firebase documents, in bytes', () {
    expect(campaignPushImageMaxBytes, 1024 * 1024);
  });

  test('a picture under the ceiling is uploaded untouched', () async {
    final image = await _fit(campaignPushImageMaxBytes);

    expect(image.fileName, 'offer.png');
    expect(image.type, 'image/png');
    expect(image.bytes.length, campaignPushImageMaxBytes);
  });

  test(
    'a picture over the ceiling becomes the JPEG it was shrunk to',
    () async {
      final jpeg = _bytesOf(400 * 1024);
      final image = await _fit(
        2 * 1024 * 1024,
        shrink: (bytes) async {
          expect(bytes.length, 2 * 1024 * 1024);
          return jpeg;
        },
      );

      expect(image.bytes, same(jpeg));
      expect(image.fileName, 'offer.jpg');
      expect(image.type, 'image/jpeg');
    },
  );

  test('a picture that cannot be decoded is refused, not sent as a banner', () {
    expect(
      () => _fit(2 * 1024 * 1024, shrink: (bytes) async => null),
      throwsA(
        isA<AdminProductException>().having(
          (e) => e.message,
          'message',
          S.imageTooLarge,
        ),
      ),
    );
  });

  test('a picture still over the ceiling after shrinking is refused', () {
    expect(
      () => _fit(
        2 * 1024 * 1024,
        shrink: (bytes) async => _bytesOf(3 * 1024 * 1024),
      ),
      throwsA(isA<AdminProductException>()),
    );
  });

  test('empty bytes are refused before anything reaches the bucket', () {
    expect(
      () => _fit(0),
      throwsA(
        isA<AdminProductException>().having(
          (e) => e.message,
          'message',
          S.imageIsEmpty,
        ),
      ),
    );
  });

  test(
    'the real shrink turns an oversized picture into a banner JPEG',
    () async {
      // صورة ضوضاء حقيقية لا بايتات مختلقة: ما تقيسه هذه الحالة هو الترميز
      // الذي سيجري على الجهاز قبل الرفع، وهو نفسه الذي أخفق في حملة 1.05MB.
      final raw = Uint8List(1000 * 800 * 4);
      final noise = math.Random(7);
      for (var i = 0; i < raw.length; i++) {
        raw[i] = noise.nextInt(256);
      }
      final png = Uint8List.fromList(
        img.encodePng(
          img.Image.fromBytes(
            width: 1000,
            height: 800,
            bytes: raw.buffer,
            numChannels: 4,
          ),
        ),
      );
      expect(png.length, greaterThan(campaignPushImageMaxBytes));

      final image = await campaignPushImageOf(
        bytes: png,
        fileName: 'offer.png',
        contentType: 'image/png',
      );

      expect(image.bytes.length, lessThanOrEqualTo(campaignPushImageMaxBytes));
      expect(image.fileName, 'offer.jpg');
      expect(image.type, 'image/jpeg');
      expect(image.bytes[0], 0xff);
      expect(image.bytes[1], 0xd8);
    },
  );
}
