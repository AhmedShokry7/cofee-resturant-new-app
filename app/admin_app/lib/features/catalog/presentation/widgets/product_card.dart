import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_image.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_rows.dart';

/// The product record card.
///
/// The layout follows the design exactly: the square image with its media
/// actions, the rows of bordered boxes, the footer row and the tinted save bar.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onEdit,
    this.onToggleFeatured,
    this.onDelete,
    this.onSave,
  });

  final AdminProduct product;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleFeatured;
  final VoidCallback? onDelete;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProductCardImage(
            imageUrl: product.imageUrl,
            isFeatured: product.isFeatured,
            onChangeImage: onEdit,
            onDelete: onDelete,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.md,
              left: AppDimensions.md,
              right: AppDimensions.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductCardNameRow(product: product, onMore: onEdit),
                const SizedBox(height: AppDimensions.md),
                ProductCardPriceRow(product: product, onMore: onEdit),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.md,
              left: AppDimensions.md,
              right: AppDimensions.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductCardOptionsRow(
                  product: product,
                  onToggleFeatured: onToggleFeatured,
                  onMore: onEdit,
                ),
                const SizedBox(height: AppDimensions.md),
                ProductCardSelectRow(
                  label: S.addCategoryShort,
                  value: product.categoryName.isEmpty
                      ? S.selectProductCategory
                      : product.categoryName,
                  muted: product.categoryName.isEmpty,
                  onTap: onEdit,
                ),
                const SizedBox(height: AppDimensions.md),
                ProductCardSelectRow(
                  label: S.localCategory,
                  value: S.selectLocalCategory,
                  muted: true,
                  onTap: onEdit,
                ),
              ],
            ),
          ),
          _ProductCardFooter(onMore: onEdit, onProductData: onEdit),
          _ProductCardSaveBar(onPressed: onSave ?? onEdit),
        ],
      ),
    );
  }
}

/// The "more" and "product data" row above the save bar.
class _ProductCardFooter extends StatelessWidget {
  const _ProductCardFooter({required this.onMore, required this.onProductData});

  final VoidCallback? onMore;
  final VoidCallback? onProductData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onMore,
              child: SizedBox(
                height: AppDimensions.recordFooterHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(HugeIcons.strokeRoundedMoreHorizontal, size: 16),
                    const SizedBox(width: AppDimensions.xs),
                    Text(
                      S.more,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: theme.colorScheme.surface,
              child: InkWell(
                onTap: onProductData,
                child: Container(
                  height: AppDimensions.recordFooterHeight,
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppDimensions.recordFieldRadius),
                    ),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    S.productData,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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

/// The tinted bar that holds the save action.
class _ProductCardSaveBar extends StatelessWidget {
  const _ProductCardSaveBar({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.cardFooter,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: AppDimensions.recordSaveBarHeight,
          child: Center(
            child: Text(
              S.save,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColor.primaryColor),
            ),
          ),
        ),
      ),
    );
  }
}
