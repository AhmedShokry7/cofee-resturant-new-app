import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';

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
  });

  /// Every loaded category; the grid filters them with [search].
  final List<AdminCategory> categories;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminCategory>? onEdit;
  final ValueChanged<AdminCategory>? onDelete;
  final ValueChanged<AdminCategory>? onToggleActive;
  final ValueChanged<AdminCategory>? onChangeImage;

  @override
  Widget build(BuildContext context) {
    final categories = filterCategories(this.categories, search);
    if (categories.isEmpty) {
      return Center(
        child: Text(
          S.noCategoriesFound,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
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
  });

  final AdminCategory category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onChangeImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColor.recordTextStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.productsCount(category.productCount),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColor.greyColor),
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
    final image = url?.trim();
    if (image == null || image.isEmpty) {
      return const ColoredBox(
        color: AppColor.imagePlaceholder,
        child: Center(
          child: Icon(
            HugeIcons.strokeRoundedFolder01,
            size: 40,
            color: AppColor.greyColor,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      placeholder: (context, url) => const ColoredBox(
        color: AppColor.imagePlaceholder,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => const ColoredBox(
        color: AppColor.imagePlaceholder,
        child: Center(
          child: Icon(
            HugeIcons.strokeRoundedFolder01,
            size: 40,
            color: AppColor.greyColor,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColor.primaryColor, fontSize: 12),
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
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColor.recordBorder)),
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
                    const Icon(
                      HugeIcons.strokeRoundedEdit01,
                      size: 14,
                      color: AppColor.recordText,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      S.edit,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.recordText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AppColor.recordBorder),
                ),
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
                        color: onToggleActive == null
                            ? AppColor.greyColor
                            : AppColor.primaryColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isActive ? S.active : S.inactive,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onToggleActive == null
                              ? AppColor.greyColor
                              : AppColor.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: AppColor.recordBorder),
                ),
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
