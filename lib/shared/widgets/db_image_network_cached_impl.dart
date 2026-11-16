import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/widgets/db_image_network.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

/// The default network picture: cached bytes on the device.
///
/// الشكل الافتراضي لصورة الشبكة: تحميل مخزّن مؤقتًا على القرص، مع مؤشر تحميل
/// ومكانه المحايد عند الفشل — نفس سلوك DbImage قبل أن تُقسَم المنصّات.
///
/// This class is imported directly (not through the conditional export) so
/// the web build can still choose it for CORS-friendly hosts.
class DbCachedNetworkImage extends DbNetworkImage {
  const DbCachedNetworkImage({
    super.key,
    required super.url,
    required super.fit,
    required super.alignment,
    super.width,
    super.height,
    required super.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      memCacheWidth: (width != null && width!.isFinite && width! > 0)
          ? width!.toInt()
          : null,
      memCacheHeight: (height != null && height!.isFinite && height! > 0)
          ? height!.toInt()
          : null,
      // Shimmer fills the exact image bounds so the layout never jumps
      // when the photo arrives. The error/empty states stay static and
      // neutral on purpose: a missing picture is not loading.
      placeholder: (context, url) => Shimmer(
        child: ShimmerBox(width: width, height: height),
      ),
      errorWidget: (context, url, error) =>
          _UnavailableDbImage(iconSize: iconSize),
    );
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
