import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

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

  @override
  Widget build(BuildContext context) {
    final url = image?.trim() ?? '';
    Widget content;
    if (url.isEmpty) {
      content = _UnavailableDbImage(iconSize: iconSize);
    } else if (_isNetwork) {
      content = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        memCacheWidth: (width != null && width!.isFinite && width! > 0) ? width!.toInt() : null,
        memCacheHeight: (height != null && height!.isFinite && height! > 0) ? height!.toInt() : null,
        // Shimmer fills the exact image bounds so the layout never jumps
        // when the photo arrives. The error/empty states stay static and
        // neutral on purpose: a missing picture is not loading.
        placeholder: (context, url) => Shimmer(
          child: ShimmerBox(width: width, height: height),
        ),
        errorWidget: (context, url, error) =>
            _UnavailableDbImage(iconSize: iconSize),
      );
    } else {
      content = Image.asset(
        url,
        fit: fit,
        width: width,
        height: height,
        cacheWidth: (width != null && width!.isFinite && width! > 0) ? width!.toInt() : null,
        cacheHeight: (height != null && height!.isFinite && height! > 0) ? height!.toInt() : null,
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
        Icons.image_not_supported,
        color: AppColor.greyColor,
        size: iconSize,
      ),
    ),
  );
}
