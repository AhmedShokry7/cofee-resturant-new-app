import 'package:flutter/material.dart';

import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/db_image_network.dart';
import 'package:new_coffee/shared/widgets/db_image_network_cached_impl.dart';

/// Single renderer for every image that comes from the database.
///
/// - `http(s)` URL  -> [CachedNetworkImage] (cached, with loader + fallback).
/// - bundled asset  -> [Image.asset] (offline catalogue rows use these).
/// - null / empty  -> neutral unavailable placeholder, never a crash.
///
/// All DB-backed pictures in the app must go through this widget so caching
/// and failure behaviour stay identical on every screen.
class DbImage extends StatelessWidget {
  const DbImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.iconSize = 24,
  });

  /// Raw value from the database column. May be a URL, an asset path, or
  /// null/empty when the row carries no picture.
  final String? image;
  final BoxFit fit;

  /// Where the picture sits in its space, as the dashboard set it.
  final Alignment alignment;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final double iconSize;

  /// The ways a picture can fill its space, with the names the database uses.
  static BoxFit fitFromName(String? name) {
    for (final fit in const <BoxFit>[
      BoxFit.cover,
      BoxFit.contain,
      BoxFit.fill,
      BoxFit.fitWidth,
      BoxFit.fitHeight,
      BoxFit.scaleDown,
      BoxFit.none,
    ]) {
      if (fit.name == name) return fit;
    }
    return BoxFit.cover;
  }

  /// The places a picture can sit in its space, with the names the database
  /// uses.
  static Alignment alignmentFromName(String? name) {
    const places = <String, Alignment>{
      'center': Alignment.center,
      'topCenter': Alignment.topCenter,
      'topLeft': Alignment.topLeft,
      'topRight': Alignment.topRight,
      'centerLeft': Alignment.centerLeft,
      'centerRight': Alignment.centerRight,
      'bottomLeft': Alignment.bottomLeft,
      'bottomCenter': Alignment.bottomCenter,
      'bottomRight': Alignment.bottomRight,
    };
    return places[name] ?? Alignment.center;
  }

  bool get _isNetwork {
    final url = image?.trim() ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Whether the picture's host sends the CORS header the web renderer
  /// needs. Our own storage does (`Access-Control-Allow-Origin: *`), so its
  /// pictures keep the cached, shimmered path on the web; every other host
  /// goes through the picture element instead.
  bool _isCorsFriendly(String url) =>
      url.startsWith(AppConfig.supabaseUrl) ||
      (AppConfig.supabaseReadUrl.isNotEmpty &&
          url.startsWith(AppConfig.supabaseReadUrl));

  @override
  Widget build(BuildContext context) {
    final url = image?.trim() ?? '';
    Widget content;
    if (url.isEmpty) {
      content = _UnavailableDbImage(iconSize: iconSize);
    } else if (_isNetwork) {
      // The platform decides how the bytes are fetched: the device caches
      // them on disk; the web build composites an `<img>` element for hosts
      // that send no CORS headers (the browser renderer refuses their bytes
      // otherwise). Our own storage sends `*`, so it keeps the richer cached
      // path - which also survives masks and continuous scrollers like the
      // home marquee, where platform views on the web cannot be trusted.
      content = _isCorsFriendly(url)
          ? DbCachedNetworkImage(
              url: url,
              fit: fit,
              alignment: alignment,
              width: width,
              height: height,
              iconSize: iconSize,
            )
          : DbNetworkImageImpl(
              url: url,
              fit: fit,
              alignment: alignment,
              width: width,
              height: height,
              iconSize: iconSize,
            );
    } else {
      content = Image.asset(
        url,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: (width != null && width!.isFinite && width! > 0)
            ? width!.toInt()
            : null,
        cacheHeight: (height != null && height!.isFinite && height! > 0)
            ? height!.toInt()
            : null,
        errorBuilder: (context, error, stackTrace) =>
            _UnavailableDbImage(iconSize: iconSize),
      );
    }
    final radius = borderRadius;
    if (radius == null) return content;
    return ClipRRect(borderRadius: radius, child: content);
  }
}

class _UnavailableDbImage extends StatelessWidget {
  const _UnavailableDbImage({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColor.surfaceColor,
    child: Center(
      child: Icon(
        AppIcons.imageMissing,
        color: AppColor.greyColor,
        size: iconSize,
      ),
    ),
  );
}
