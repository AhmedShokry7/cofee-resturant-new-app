import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card.dart';

/// Responsive product-card grid. Cards keep the Figma proportions while
/// adapting to the width available in the page.
class ProductRecords extends StatelessWidget {
  const ProductRecords({
    super.key,
    required this.products,
    this.categories = const <AdminCategory>[],
    this.onSave,
    this.onToggleFeatured,
    this.onDelete,
    this.onSelect,
    this.onOpenImages,
    this.onCreateCategory,
    this.selectedIds = const <String>{},
    this.savingProductId,
    this.footer,
  });

  final List<AdminProduct> products;
  final List<AdminCategory> categories;
  final ValueChanged<AdminProduct>? onSave;
  final ValueChanged<AdminProduct>? onToggleFeatured;
  final ValueChanged<AdminProduct>? onDelete;

  /// Picks the product for a bulk action.
  final ValueChanged<AdminProduct>? onSelect;

  /// Opens the gallery of the pictures of a product.
  final ValueChanged<AdminProduct>? onOpenImages;

  /// Creates a category of its own and hands it back to the card.
  final Future<AdminCategory?> Function(
    String nameAr,
    String nameEn, [
    String? descriptionAr,
    String? descriptionEn,
  ])?
  onCreateCategory;

  /// The products that are picked for a bulk action.
  final Set<String> selectedIds;

  /// The product the dashboard is writing right now.
  final String? savingProductId;

  /// A row under the grid, such as the marker of the page being loaded.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = AppSpacing.lg;
        final columns = _columnsFor(constraints.maxWidth, spacing);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final product in products)
              SizedBox(
                width: width,
                child: ProductCard(
                  product: product,
                  categories: categories,
                  isSaving: savingProductId == product.id,
                  isSelected: selectedIds.contains(product.id),
                  onSave: onSave == null ? null : (product) => onSave!(product),
                  onToggleFeatured: onToggleFeatured == null
                      ? null
                      : () => onToggleFeatured!(product),
                  onDelete: onDelete == null ? null : () => onDelete!(product),
                  onSelect: onSelect == null ? null : () => onSelect!(product),
                  onOpenImages: onOpenImages == null
                      ? null
                      : () => onOpenImages!(product),
                  onCreateCategory: onCreateCategory,
                ),
              ),
            if (footer != null)
              SizedBox(width: constraints.maxWidth, child: footer),
          ],
        );
      },
    );
  }

  int _columnsFor(double availableWidth, double spacing) {
    if (availableWidth <= 0) return 1;
    const minCardWidth = AppDimensions.productCardMinWidth;
    final columns = ((availableWidth + spacing) / (minCardWidth + spacing))
        .floor();
    return columns.clamp(1, AppDimensions.productCardMaxColumns);
  }
}
