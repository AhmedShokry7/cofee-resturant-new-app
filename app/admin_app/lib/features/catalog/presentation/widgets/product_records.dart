import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card.dart';

/// The product records shown as cards.
///
/// The grid fits as many cards as the available width allows: five on very
/// wide screens, four on a normal desktop, then three, two and one.
class ProductRecords extends StatelessWidget {
  const ProductRecords({
    super.key,
    required this.products,
    this.onEdit,
    this.onToggleFeatured,
    this.onDelete,
    this.onSave,
  });

  final List<AdminProduct> products;
  final ValueChanged<AdminProduct>? onEdit;
  final ValueChanged<AdminProduct>? onToggleFeatured;
  final ValueChanged<AdminProduct>? onDelete;
  final ValueChanged<AdminProduct>? onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final spacing = AppDimensions.lg;
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
                  onEdit: onEdit == null ? null : () => onEdit!(product),
                  onToggleFeatured: onToggleFeatured == null
                      ? null
                      : () => onToggleFeatured!(product),
                  onDelete: onDelete == null ? null : () => onDelete!(product),
                  onSave: onSave == null ? null : () => onSave!(product),
                ),
              ),
          ],
        );
      },
    );
  }

  /// How many cards fit in the given width.
  ///
  /// The card keeps a minimum width, so the column count follows the space
  /// that is really available instead of the device label.
  int _columnsFor(double availableWidth) {
    if (availableWidth <= 0) return 1;
    const minCardWidth = AppDimensions.productCardMinWidth;
    const spacing = AppDimensions.lg;
    final columns = ((availableWidth + spacing) / (minCardWidth + spacing))
        .floor();
    return columns.clamp(1, AppDimensions.productCardMaxColumns);
  }
}
