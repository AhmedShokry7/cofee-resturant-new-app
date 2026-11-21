import 'package:flutter/foundation.dart';

import 'package:admin_app/core/catalog/admin_product_exception.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/admin_image_bytes.dart';
import 'package:admin_app/core/services/admin_image_picker.dart';

/// سقف صورة الإشعار عند FCM، وهو حدّ صارم لا نصيحة: ما يتجاوزه يُحذف بصمت
/// فيطبع الجهاز بانر نصّيًا بلا صورة، بينما يبقى النصّ والنقر يعملان.
const int campaignPushImageMaxBytes = 1024 * 1024;

/// الصورة كما تُرفع للدلو: البادئة والاسم والنوع قد تتغير حين تُصغَّر.
typedef CampaignPushImage = ({Uint8List bytes, String fileName, String type});

/// ما يقرأه `img` داخل معزل منفصل، فلا يُفكّ ترميز صورة كبيرة على خيط الواجهة.
Uint8List? _shrinkToJpeg(Uint8List bytes) => adminImageShrinkToJpeg(
  bytes,
  adminImageQuality,
  maxBytes: campaignPushImageMaxBytes,
);

/// الصورة التي تقبلها FCM لحملة، أو رفضٌ صريح إذا لم تُصغَّر إلى الحد.
///
/// تحت السقف تمرّ الصورة كما انتقاها الموظف، فلا يُعاد ترميز شيء سليم. وفوقه
/// تُصغَّر إلى JPEG بجودة الرفع المشتركة نفسها؛ وإن بقيت أكبر من السقف بعد
/// الترميز فأفضل من بانر بلا صورة أن نقول للموظف إن الصورة كبيرة.
Future<CampaignPushImage> campaignPushImageOf({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
  Future<Uint8List?> Function(Uint8List)? shrink,
}) async {
  if (bytes.isEmpty) throw AdminProductException(S.imageIsEmpty);
  final detectedType = adminImageSniffedType(bytes) ?? contentType;
  // FCM documents JPEG and PNG as fully supported across platforms. WebP and
  // other formats have device-dependent support. BMP is not supported by the
  // upload path's content-type/extension pairing, so normalize it too.
  final fcmSafeType = const {'image/jpeg', 'image/png'}
      .contains(detectedType.toLowerCase());
  final needsJpeg = bytes.length > campaignPushImageMaxBytes || !fcmSafeType;
  if (!needsJpeg) {
    final normalizedType = detectedType.toLowerCase();
    final extension = normalizedType == 'image/png' ? '.png' : '.jpg';
    return (
      bytes: bytes,
      fileName: _fileNameWithExtension(fileName, extension),
      type: normalizedType,
    );
  }

  final shrunk = await (shrink?.call(bytes) ?? compute(_shrinkToJpeg, bytes));
  if (shrunk == null || shrunk.length > campaignPushImageMaxBytes) {
    throw AdminProductException(S.imageTooLarge);
  }
  return (
    bytes: shrunk,
    fileName: adminImageJpegName(fileName),
    type: 'image/jpeg',
  );
}

String _fileNameWithExtension(String fileName, String extension) {
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$stem$extension';
}
