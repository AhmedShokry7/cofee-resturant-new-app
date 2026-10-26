import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_selection_checkbox.dart';

/// The categories whose name or description holds [search].
List<AdminCategory> filterCategories(
  List<AdminCategory> categories,
  String search,
) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return categories;
  return categories
      .where(
        (c) =>
            c.nameAr.toLowerCase().contains(q) ||
            c.nameEn.toLowerCase().contains(q) ||
            (c.descriptionAr?.toLowerCase().contains(q) ?? false) ||
            (c.descriptionEn?.toLowerCase().contains(q) ?? false),
      )
      .toList(growable: false);
}

/// The grid of category cards.
class CategoryRecords extends StatelessWidget {
  const CategoryRecords({
    super.key,
    required this.categories,
    this.search = '',
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
    this.onChangeImage,
    this.selectedIds = const <String>{},
    this.onSelect,
  });

  /// Every loaded category; the grid filters them with [search].
  final List<AdminCategory> categories;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminCategory>? onEdit;
  final ValueChanged<AdminCategory>? onDelete;
  final ValueChanged<AdminCategory>? onToggleActive;
  final ValueChanged<AdminCategory>? onChangeImage;

  /// The categories that are picked for a bulk action.
  final Set<String> selectedIds;

  final ValueChanged<AdminCategory>? onSelect;

  @override
  Widget build(BuildContext context) {
    final categories = filterCategories(this.categories, search);
    if (categories.isEmpty) {
      final filtering = search.trim().isNotEmpty;
      return AdminEmptyState(
        icon: filtering
            ? HugeIcons.strokeRoundedSearch01
            : HugeIcons.strokeRoundedFolder01,
        message: filtering ? S.noCategoriesFound : S.noCategoriesYet,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns;
        if (width > 1400) {
          columns = 5;
        } else if (width > 1100) {
          columns = 4;
        } else if (width > 800) {
          columns = 3;
        } else if (width > 500) {
          columns = 2;
        } else {
          columns = 1;
        }

        final cardWidth = (width - (columns - 1) * AppDimensions.md) / columns;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppDimensions.md,
            mainAxisSpacing: AppDimensions.md,
            childAspectRatio: cardWidth / (cardWidth + 100),
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryCard(
              category: category,
              onEdit: onEdit == null ? null : () => onEdit!(category),
              onDelete: onDelete == null ? null : () => onDelete!(category),
              onToggleActive: onToggleActive == null
                  ? null
                  : () => onToggleActive!(category),
              onChangeImage: onChangeImage == null
                  ? null
                  : () => onChangeImage!(category),
              isSelected: selectedIds.contains(category.id),
              onSelect: onSelect == null ? null : () => onSelect!(category),
            );
          },
        );
      },
    );
  }
}

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
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
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
                const SizedBox(height: 4),
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
          child: Icon(
            HugeIcons.strokeRoundedFolder01,
            size: 40,
            color: iconColor,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      placeholder: (context, url) => ColoredBox(
        color: background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: background,
        child: Center(
          child: Icon(
            HugeIcons.strokeRoundedFolder01,
            size: 40,
            color: iconColor,
          ),
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
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                HugeIcons.strokeRoundedCancel01,
                size: 12,
                color: AppColor.whiteColor,
              ),
              const SizedBox(width: 4),
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
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              const SizedBox(width: 5),
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
                    Icon(
                      HugeIcons.strokeRoundedEdit01,
                      size: 14,
                      color: textColor,
                    ),
                    const SizedBox(width: 5),
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
                            ? HugeIcons.strokeRoundedCheckmarkCircle01
                            : HugeIcons.strokeRoundedCancelCircle,
                        size: 14,
                        color: onToggleActive == null ? muted : activeColor,
                      ),
                      const SizedBox(width: 5),
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
                        HugeIcons.strokeRoundedDelete01,
                        size: 14,
                        color: AppColor.errorColor,
                      ),
                      const SizedBox(width: 5),
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
