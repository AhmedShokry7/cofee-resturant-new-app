import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// A rounded network image with a quiet icon while it loads.
class AdminNetworkThumb extends StatelessWidget {
  const AdminNetworkThumb({
    super.key,
    this.imageUrl,
    this.size = 46,
    this.icon = AppIcons.package,
    this.width,
    this.height,
    this.fit = BoxFit.fill,
    this.borderRadius,
  });

  final String? imageUrl;
  final double size;
  final IconData icon;

  /// Overrides [size] for the horizontal or vertical extent when a banner
  /// image needs to fill its slot instead of staying square.
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = imageUrl?.trim() ?? '';
    final fetchable = url.startsWith('http://') || url.startsWith('https://');
    final resolvedWidth = width ?? size;
    final resolvedHeight = height ?? size;
    final shortest = resolvedWidth < resolvedHeight
        ? resolvedWidth
        : resolvedHeight;
    final fallback = ColoredBox(
      color: adminTintedSurfaceColor(theme),
      child: AppIcon(icon, size: shortest * .4, color: adminMutedColor(theme)),
    );
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * .2),
      child: SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: fetchable
            ? CachedNetworkImage(
                imageUrl: url,
                fit: fit,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}
