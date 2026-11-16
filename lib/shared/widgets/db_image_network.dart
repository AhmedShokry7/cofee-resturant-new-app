import 'package:flutter/material.dart';

export 'db_image_network_cached.dart'
    if (dart.library.js_interop) 'db_image_network_dom.dart';

/// One doorway for every network picture [DbImage] draws.
///
/// The platform implementations live behind the conditional export above and
/// share this base class:
///
/// - default (mobile): [CachedNetworkImage] with the app's disk cache;
/// - web: an `<img>` element behind a platform view, because the browser
///   renderer decodes pictures from bytes it fetches itself, and it refuses
///   hosts that send no `Access-Control-Allow-Origin` header - which is
///   exactly what the merchant's menu image server does. The picture element
///   composites without those headers, so product photos survive on the web
///   preview too.
///
/// نقطة العبور الوحيدة لكل صورة شبكة يرسمها DbImage: التخزين المؤقت على
/// الهاتف، وعنصر الصورة الأصلي في المتصفح كي لا تُمنع صور المواقع الأجنبية
/// بعناوين CORS.
abstract class DbNetworkImage extends StatelessWidget {
  const DbNetworkImage({
    super.key,
    required this.url,
    required this.fit,
    required this.alignment,
    this.width,
    this.height,
    required this.iconSize,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final double iconSize;
}
