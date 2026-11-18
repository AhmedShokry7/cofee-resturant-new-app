import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
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
    // The picture is decoded at the size it is drawn at, not at the size of
    // the file: a list of thumbnails must not hold full originals in memory.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memWidth = (resolvedWidth * dpr).round().clamp(64, 512);
    final memHeight = (resolvedHeight * dpr).round().clamp(64, 512);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * .2),
      child: SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: fetchable
            ? CachedNetworkImage(
                imageUrl: url,
                fit: fit,
                memCacheWidth: memWidth,
                memCacheHeight: memHeight,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}
