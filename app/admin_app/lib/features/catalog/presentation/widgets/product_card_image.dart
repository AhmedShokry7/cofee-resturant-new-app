import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

/// Product image area styled after the Figma reference.
class ProductCardImage extends StatelessWidget {
  const ProductCardImage({
    super.key,
    required this.imageUrl,
    required this.isSelected,
    required this.isFeatured,
    this.onChangeImage,
    this.onSelect,
    this.onOpenImages,
    this.fit = BoxFit.fill,
    this.alignment = Alignment.center,
  });

  final String? imageUrl;

  /// The product is picked for a bulk action.
  final bool isSelected;

  final bool isFeatured;
  final VoidCallback? onChangeImage;
  final VoidCallback? onSelect;

  /// Opens the gallery of the pictures of the product.
  final VoidCallback? onOpenImages;

  /// How the picture fills its space.
  final BoxFit fit;

  /// Where the picture sits in its space.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The picture opens the gallery of the product.
          GestureDetector(
            onTap: (imageUrl != null && imageUrl!.trim().isNotEmpty)
                ? (onOpenImages ?? onChangeImage)
                : (onChangeImage ?? onOpenImages),
            behavior: HitTestBehavior.opaque,
            child: _CoverImage(url: imageUrl, fit: fit, alignment: alignment),
          ),
          if (onSelect != null)
            PositionedDirectional(
              top: AppDimensions.recordImageInset,
              end: AppDimensions.recordImageInset,
              child: AdminSelectionCheckBox(
                checked: isSelected,
                onTap: onSelect,
              ),
            ),
          if (isFeatured)
            PositionedDirectional(
              top: AppDimensions.recordImageInset,
              start: AppDimensions.recordImageInset,
              child: const _FeaturedBadge(),
            ),
          if (onChangeImage != null)
            PositionedDirectional(
              bottom: AppDimensions.recordImageInset,
              start: AppDimensions.recordImageInset,
              child: _MediaPill(onTap: onChangeImage),
            ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.url,
    this.fit = BoxFit.fill,
    this.alignment = Alignment.center,
  });
  final String? url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final image = url?.trim();
    if (image == null || image.isEmpty) {
      return const _ImagePlaceholder();
    }

    // The picture is cached on the device: the catalogue shows the same
    // pictures again and again, so they are fetched once.
    return CachedNetworkImage(
      imageUrl: image,
      fit: fit,
      alignment: alignment,
      placeholder: (context, url) => const _ImagePlaceholder(),
      errorWidget: (context, url, error) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? AppColor.darkSurfaceContainer : AppColor.imagePlaceholder,
      child: Center(
        child: Icon(
          AppIcons.image01,
          size: 40,
          color: dark ? AppColor.darkTextSecondary : AppColor.greyColor,
        ),
      ),
    );
  }
}

/// The mark of a product that is featured in the store.
class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColor.primaryColor,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          S.featured,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColor.whiteColor,
            fontSize: AppFontSizes.size11,
            fontWeight: AppFontWeights.semiBold,
          ),
        ),
      ),
    );
  }
}

class _MediaPill extends StatelessWidget {
  const _MediaPill({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.whiteColor,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.addImageOrVideo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColor.primaryColor,
                  fontSize: AppFontSizes.size12,
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              const Icon(
                AppIcons.imageAdd01,
                size: 14,
                color: AppColor.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
