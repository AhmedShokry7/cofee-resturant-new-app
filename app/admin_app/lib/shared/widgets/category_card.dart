import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

/// A category card: image area on top, name and product count below.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.countLabel,
    this.isSelected = false,
    this.onSelect,
  });

  final AdminCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onChangeImage;

  /// Overrides the product count under the name, such as the number of
  /// components of a bundle.
  final String? countLabel;

  /// The category is picked for a bulk action.
  final bool isSelected;

  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.recordBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image area
          AspectRatio(
            aspectRatio: 1,
            child: GestureDetector(
              onTap: onChangeImage,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CategoryImage(url: category.imageUrl),
                  PositionedDirectional(
                    top: AppDimensions.recordImageInset,
                    end: AppDimensions.recordImageInset,
                    child: AdminSelectionCheckBox(
                      checked: isSelected,
                      onTap: onSelect,
                    ),
                  ),
                  if (!category.isActive)
                    PositionedDirectional(
                      top: AppDimensions.recordImageInset,
                      start: AppDimensions.recordImageInset,
                      child: _InactiveBadge(onTap: onToggleActive),
                    ),
                  PositionedDirectional(
                    bottom: AppDimensions.recordImageInset,
                    start: AppDimensions.recordImageInset,
                    child: _ImagePill(onTap: onChangeImage),
                  ),
                ],
              ),
            ),
          ),
          // Name and count
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.nameFor(AppLocale.instance.language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: AppFontWeights.semiBold,
                    color: dark ? AppColor.darkText : AppColor.recordTextStrong,
                  ),
                ),
                const SizedBox(height: AppSizes.px4),
                Text(
                  countLabel ?? S.productsCount(category.productCount),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          // Footer
          _CategoryCardFooter(
            isActive: category.isActive,
            onEdit: onEdit,
            onDelete: onDelete,
            onToggleActive: onToggleActive,
          ),
        ],
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? AppColor.darkSurfaceContainer
        : AppColor.imagePlaceholder;
    final iconColor = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    final image = url?.trim();
    if (image == null || image.isEmpty) {
      return ColoredBox(
        color: background,
        child: Center(
          child: Icon(AppIcons.folder01, size: 40, color: iconColor),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.fill,
      placeholder: (context, url) => ColoredBox(
        color: background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: background,
        child: Center(
          child: Icon(AppIcons.folder01, size: 40, color: iconColor),
        ),
      ),
    );
  }
}

class _InactiveBadge extends StatelessWidget {
  const _InactiveBadge({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.errorColor,
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
              const Icon(
                AppIcons.cancel01,
                size: 12,
                color: AppColor.whiteColor,
              ),
              const SizedBox(width: AppSizes.px4),
              Text(
                S.inactive,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColor.whiteColor,
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePill extends StatelessWidget {
  const _ImagePill({this.onTap});
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

class _CategoryCardFooter extends StatelessWidget {
  const _CategoryCardFooter({
    required this.isActive,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final bool isActive;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border = dark ? AppColor.darkBorder : AppColor.recordBorder;
    final textColor = dark ? AppColor.darkTextSecondary : AppColor.recordText;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.greyColor;
    final activeColor = dark ? AppColor.secondaryColor : AppColor.primaryColor;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: SizedBox(
                height: AppDimensions.recordFooterHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.edit01, size: 14, color: textColor),
                    const SizedBox(width: AppSizes.px6),
                    Text(
                      S.edit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        fontSize: AppFontSizes.size12,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: BorderDirectional(start: BorderSide(color: border)),
              ),
              child: InkWell(
                onTap: onToggleActive,
                child: SizedBox(
                  height: AppDimensions.recordFooterHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive
                            ? AppIcons.checkmarkCircle01
                            : AppIcons.cancelCircle,
                        size: 14,
                        color: onToggleActive == null ? muted : activeColor,
                      ),
                      const SizedBox(width: AppSizes.px6),
                      Text(
                        isActive ? S.active : S.inactive,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onToggleActive == null ? muted : activeColor,
                          fontSize: AppFontSizes.size12,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: BorderDirectional(start: BorderSide(color: border)),
              ),
              child: InkWell(
                onTap: onDelete,
                child: SizedBox(
                  height: AppDimensions.recordFooterHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        AppIcons.delete01,
                        size: 14,
                        color: AppColor.errorColor,
                      ),
                      const SizedBox(width: AppSizes.px6),
                      Text(
                        S.delete,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColor.errorColor,
                          fontSize: AppFontSizes.size12,
                          fontWeight: AppFontWeights.medium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
