import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_page_header.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_records.dart';

/// The body of the products page.
///
/// It only composes the sections: the header and the records.
class ProductPageBody extends StatelessWidget {
  const ProductPageBody({
    super.key,
    required this.products,
    required this.onAdd,
    this.onEdit,
    this.onToggleFeatured,
    this.onDelete,
    this.onSave,
  });

  final List<AdminProduct> products;
  final VoidCallback onAdd;
  final ValueChanged<AdminProduct>? onEdit;
  final ValueChanged<AdminProduct>? onToggleFeatured;
  final ValueChanged<AdminProduct>? onDelete;
  final ValueChanged<AdminProduct>? onSave;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductPageHeader(count: products.length, onAdd: onAdd),
          const SizedBox(height: AppDimensions.lg),
          ProductRecords(
            products: products,
            onEdit: onEdit,
            onToggleFeatured: onToggleFeatured,
            onDelete: onDelete,
            onSave: onSave,
          ),
        ],
      ),
    );
  }
}
