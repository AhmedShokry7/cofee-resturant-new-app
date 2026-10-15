import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

/// Renders either a database URL or a bundled asset used by the offline menu.
class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.product,
    this.fit = BoxFit.cover,
  });

  final ProductModel product;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final image = product.displayImageUrl;
    if (image == null) return const _UnavailableProductImage();

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: image,
        fit: fit,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const _UnavailableProductImage(),
      );
    }

    return Image.asset(
      image,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          const _UnavailableProductImage(),
    );
  }
}

class _UnavailableProductImage extends StatelessWidget {
  const _UnavailableProductImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColor.surfaceColor,
    child: Center(
      child: Icon(
        Icons.image_not_supported,
        color: AppColor.greyColor,
        size: 24,
      ),
    ),
  );
}
