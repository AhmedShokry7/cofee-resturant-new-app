import 'package:image_picker/image_picker.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product_image.dart';

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
/// The file is measured before it is read: a picture that the bucket of the
/// catalogue would refuse is said so at once, instead of being carried into
/// the memory of the page and rejected after a round trip to the server.
Future<ProductImageSource> adminImageSourceOf(XFile picked) async {
  final size = await picked.length();
  if (size == 0) {
    throw AdminProductException(S.imageIsEmpty);
  }
  if (size > adminImageMaxBytes) {
    throw AdminProductException(S.imageTooLarge);
  }
  final bytes = await picked.readAsBytes();
  return ProductImageSource.file(
    bytes,
    picked.name,
    adminImageContentTypeOf(picked.name, picked.mimeType),
  );
}

/// The type of a picture file, from its name and what the device says.
String adminImageContentTypeOf(String fileName, String? mimeType) {
  final name = fileName.trim().toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  return mimeType ?? 'image/jpeg';
}
