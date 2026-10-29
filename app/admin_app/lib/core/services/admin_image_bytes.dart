import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'package:admin_app/core/constants/app_dimensions.dart';

/// The format the bytes really are, whatever the name of the file claims.
///
/// The browser of the dashboard re-encodes a picked picture and keeps the
/// name and the type of the original file, so a picture named `.bmp` arrives
/// as PNG bytes. Trusting the name alone refuses pictures that the bucket
/// would accept.
String? adminImageSniffedType(Uint8List bytes) {
  if (bytes.length < 4) return null;
  if (bytes[0] == 0xff && bytes[1] == 0xd8) return 'image/jpeg';
  if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
  if (_ascii(bytes, 0, 'RIFF') && _ascii(bytes, 8, 'WEBP')) return 'image/webp';
  if (_ascii(bytes, 0, 'GIF8')) return 'image/gif';
  return null;
}

bool _ascii(Uint8List bytes, int at, String marker) {
  if (bytes.length < at + marker.length) return false;
  for (var i = 0; i < marker.length; i++) {
    if (bytes[at + i] != marker.codeUnitAt(i)) return false;
  }
  return true;
}

/// The picture shrunk to a JPEG the bucket accepts, or null when it cannot be
/// read at all.
///
/// The browser only applies a quality to JPEG and WEBP output, so a large PNG
/// comes back from it still large. Re-encoding here is what lets a screenshot
/// or a logo of a category reach the panel instead of being refused.
Uint8List? adminImageShrinkToJpeg(Uint8List bytes, int quality) {
  final picture = img.decodeImage(bytes);
  if (picture == null) return null;
  final edge = AppDimensions.imagePreviewCacheWidth.round() * 2;
  final scaled = picture.width > edge || picture.height > edge
      ? img.copyResize(
          picture,
          width: edge,
          height: edge,
          interpolation: img.Interpolation.average,
        )
      : picture;
  return Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
}
