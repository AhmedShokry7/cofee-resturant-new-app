import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// The square image of the product card with its media actions.
class ProductCardImage extends StatelessWidget {
  const ProductCardImage({
    super.key,
    required this.imageUrl,
    required this.isFeatured,
    this.onChangeImage,
    this.onDelete,
  });

  final String? imageUrl;
  final bool isFeatured;
  final VoidCallback? onChangeImage;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CoverImage(url: imageUrl),
          PositionedDirectional(
            top: AppDimensions.recordImageInset,
            end: AppDimensions.recordImageInset,
            child: _FeaturedCheckBox(checked: isFeatured),
          ),
          PositionedDirectional(
            bottom: AppDimensions.recordImageInset,
            start: AppDimensions.recordImageInset,
            child: _MediaPill(onTap: onChangeImage),
          ),
          PositionedDirectional(
            bottom: AppDimensions.recordImageInset,
            end: AppDimensions.recordImageInset,
            child: _DeleteCircle(onTap: onDelete),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final image = url?.trim();
    if (image == null || image.isEmpty) {
      return const _ImagePlaceholder();
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColor.lightGreyColor,
      child: Center(
        child: Icon(
          HugeIcons.strokeRoundedImage01,
          size: 40,
          color: AppColor.greyColor,
        ),
      ),
    );
  }
}

/// The small square check box drawn on top of the image.
class _FeaturedCheckBox extends StatelessWidget {
  const _FeaturedCheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.recordCheckBoxSize,
      height: AppDimensions.recordCheckBoxSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.recordFieldRadius),
        border: Border.all(color: AppColor.primaryColor),
      ),
      child: checked
          ? const Icon(
              HugeIcons.strokeRoundedTick01,
              size: 14,
              color: AppColor.primaryColor,
            )
          : null,
    );
  }
}

/// The white pill that opens the media picker.
class _MediaPill extends StatelessWidget {
  const _MediaPill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.whiteColor,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.addImageOrVideo,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColor.primaryColor),
              ),
              const SizedBox(width: AppDimensions.xs),
              const Icon(
                HugeIcons.strokeRoundedImageAdd01,
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

/// The red round action on the image.
class _DeleteCircle extends StatelessWidget {
  const _DeleteCircle({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.errorColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: AppDimensions.recordActionCircle,
          height: AppDimensions.recordActionCircle,
          child: Icon(
            HugeIcons.strokeRoundedDelete01,
            size: 16,
            color: AppColor.whiteColor,
          ),
        ),
      ),
    );
  }
}
