import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/db_image_network.dart';

/// The web network picture: an `<img>` element composited through a platform
/// view.
///
/// The browser image decoder fetches picture bytes itself and refuses hosts
/// that do not send `Access-Control-Allow-Origin`; the merchant's menu image
/// server is one of them, so every product photo failed in the web preview.
/// An `<img>` element is composited by the browser, not decoded by Flutter,
/// and an image element never needs CORS headers to be displayed.
///
/// Each unique URL registers one platform view once per session; the browser
/// handles the actual downloading and its own memory cache afterwards.
///
/// صورة الشبكة على الويب: عنصر `<img>` يُتركيب عبر Platform View لأن مفكك
/// صور المتصفح يمنع الاستضافة التي لا ترسل ترويسة CORS، وعنصر الصورة يُعرض
/// بلا ترويسات. كل رابط فريد يسجّل مكانه مرة واحدة في الجلسة، والمتصفح
/// يتولى التنزيل والتخزين المؤقت بعدها.
class DbNetworkImageImpl extends DbNetworkImage {
  const DbNetworkImageImpl({
    super.key,
    required super.url,
    required super.fit,
    required super.alignment,
    super.width,
    super.height,
    required super.iconSize,
  });

  /// The platform-view types this session has already registered.
  static final Map<String, String> _registered = <String, String>{};

  /// A stable, collision-free platform view type for the URL.
  static String _viewType(String url) {
    final key = base64Url.encode(utf8.encode(url));
    return 'db-image/$key';
  }

  /// BoxFit in CSS `object-fit` terms.
  String get _cssObjectFit => switch (fit) {
    BoxFit.contain => 'contain',
    BoxFit.fill => 'fill',
    BoxFit.none => 'none',
    BoxFit.scaleDown => 'scale-down',
    // cover and the width/height crops all read as "cover" to CSS; the
    // database almost always stores cover or contain anyway.
    _ => 'cover',
  };

  /// Alignment in CSS `object-position` percentages.
  String get _cssObjectPosition {
    final left = ((alignment.x + 1) / 2 * 100).clamp(0.0, 100.0);
    final top = ((alignment.y + 1) / 2 * 100).clamp(0.0, 100.0);
    return '${left.toStringAsFixed(1)}% ${top.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final type = _viewType(url);
    if (!_registered.containsKey(type)) {
      final img = web.HTMLImageElement();
      img.src = url;
      img.loading = 'eager';
      img.decoding = 'async';
      final style = img.style;
      style.width = '100%';
      style.height = '100%';
      style.objectFit = _cssObjectFit;
      style.objectPosition = _cssObjectPosition;
      style.display = 'block';
      // A picture that never arrives leaves a neutral box, not a broken
      // icon the way the raw element would.
      img.onerror = ((JSObject? _) {
        img.style.display = 'none';
      }).toJS;
      ui_web.platformViewRegistry.registerViewFactory(
        type,
        (int viewId) => img,
      );
      _registered[type] = type;
    }
    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: AppColor.surfaceColor,
        child: HtmlElementView(viewType: type),
      ),
    );
  }
}
