import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/models/admin_product_image.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_image_gallery.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_image_settings.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Opens the dialog that holds every picture of a product, after reading
/// them from the database.
Future<void> showProductImagesDialog({
  required BuildContext context,
  required AdminProductCubit cubit,
  required AdminProduct product,
}) async {
  if (product.isDraft) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.saveProductFirst)));
    return;
  }

  final List<AdminProductImage> images;
  try {
    images = await cubit.loadProductImages(
      product.id,
      fallbackImageUrl: product.imageUrl,
    );
  } catch (_) {
    if (!context.mounted) return;
    showErrorSnackBar(context, S.imageActionFailed);
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => ProductImageGallery(
      images: images,
      onReload: () => cubit.loadProductImages(product.id),
      onAdd: (source, onPhase) => cubit.addProductImageFrom(
        productId: product.id,
        source: source,
        onPhase: onPhase,
      ),
      onReplace: (image, source, onPhase) => cubit.replaceProductImageFrom(
        image: image,
        source: source,
        onPhase: onPhase,
      ),
      onDelete: cubit.deleteProductImage,
      onSetPrimary: cubit.setPrimaryProductImage,
      onEdit: (image, bytes, fileName) => cubit.replaceProductImageFrom(
        image: image,
        source: ProductImageSource.file(
          bytes,
          _pngFileName(fileName),
          'image/png',
        ),
      ),
      onApplySettings:
          ({
            required image,
            required fit,
            required alignment,
            required scope,
          }) => scope == ImageSettingsScope.allPictures
          ? cubit.applyProductImageSettings(
              productId: product.id,
              fit: fit,
              alignment: alignment,
            )
          : cubit.updateProductImageSettings(
              image: image,
              fit: fit,
              alignment: alignment,
            ),
    ),
  );
}

/// Opens the dialog that writes a new product through the cubit of the page.
Future<void> showProductDataDialog({
  required BuildContext context,
  required AdminProductCubit cubit,
  required List<AdminCategory> categories,
}) {
  final draft = AdminProduct.draft(
    'draft-${DateTime.now().microsecondsSinceEpoch}',
  );
  return showDialog<void>(
    context: context,
    builder: (context) => ProductDataDialog(
      product: draft,
      language: AppLocale.instance.language,
      categories: categories,
      cubit: cubit,
      onSave: (product) => cubit.saveProduct(product),
    ),
  );
}

String _pngFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final name = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$name.png';
}
