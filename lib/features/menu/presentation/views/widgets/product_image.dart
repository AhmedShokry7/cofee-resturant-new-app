import 'package:flutter/material.dart';

import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// Renders either a database URL or a bundled asset used by the offline menu.
///
/// Image selection lives in [ProductModel.displayImageUrl]; every rendering
/// rule (caching, loader, fallback) lives in [DbImage].
class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.product,
    this.fit = BoxFit.cover,
  });

  final ProductModel product;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => DbImage(
    image: product.displayImageUrl,
    fit: DbImage.fitFromName(product.imageFit),
    alignment: DbImage.alignmentFromName(product.imageAlignment),
  );
}
