import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/core/services/admin_image_bytes.dart';

/// The longest edge a picked picture keeps.
///
/// The browser of the dashboard resizes the picked file on the main thread:
/// a phone picture of twelve megapixels needs a canvas that big before the
/// dashboard even sees its bytes, and the tab is dropped before that work
/// ends. Keeping the edge bounded makes the picture small enough to open,
/// preview and upload, and it is still far above any space the panel shows it
/// in.
const int adminImageMaxEdge = 2048;

/// The quality the picture is re-encoded at when it is shrunk.
const int adminImageQuality = 85;

/// Picks a picture from the device and brings it in at a size the dashboard
/// can hold.
///
/// The shrink happens while the file is read, so no part of the pipeline ever
/// works on the full resolution of a phone camera. Returns null when the admin
/// closes the picker.
Future<ProductImageSource?> pickAdminImage({
  ImageSource source = ImageSource.gallery,
  Future<XFile?> Function()? pickFile,
}) async {
  final picked =
      await (pickFile?.call() ??
          ImagePicker().pickImage(
            source: source,
            maxWidth: adminImageMaxEdge.toDouble(),
            maxHeight: adminImageMaxEdge.toDouble(),
            imageQuality: adminImageQuality,
          ));
  if (picked == null) return null;
  return adminImageSourceOf(picked);
}

/// The bytes of a picked file, as the source of a picture.
///
/// The type comes from the bytes, not from the name: the browser re-encodes
/// the picture it shrinks and keeps the name of the original file, so the name
/// lies about what arrived. A picture bigger than the bucket accepts is
/// shrunk once here, because the browser only applies a quality to JPEG and
/// WEBP output and a large PNG comes back from it still large.
Future<ProductImageSource> adminImageSourceOf(XFile picked) async {
  final size = await picked.length();
  if (size == 0) {
    throw AdminProductException(S.imageIsEmpty);
  }
  final bytes = await picked.readAsBytes();
  final type =
      adminImageSniffedType(bytes) ??
      adminImageContentTypeOf(picked.name, picked.mimeType);
  if (bytes.length <= adminImageMaxBytes) {
    return ProductImageSource.file(bytes, picked.name, type);
  }

  final shrunk = await compute(_shrinkPicked, bytes);
  if (shrunk == null || shrunk.length > adminImageMaxBytes) {
    throw AdminProductException(S.imageTooLarge);
  }
  return ProductImageSource.file(
    shrunk,
    adminImageJpegName(picked.name),
    'image/jpeg',
  );
}

/// The name of a picture whose bytes became JPEG, so the extension of the
/// file in the bucket matches what it holds.
String adminImageJpegName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$stem.jpg';
}

/// The type of a picture file, from its name and what the device says.
String adminImageContentTypeOf(String fileName, String? mimeType) {
  final name = fileName.trim().toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  return mimeType ?? 'image/jpeg';
}

/// The shrink runs away from the interface thread where the dashboard can be
/// touched while a big picture is decoded.
Uint8List? _shrinkPicked(Uint8List bytes) =>
    adminImageShrinkToJpeg(bytes, adminImageQuality);
