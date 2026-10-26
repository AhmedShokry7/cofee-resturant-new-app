import 'package:flutter/material.dart';

import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';

/// Opens the dialog that replaces or removes the picture of a bundle.
Future<void> showBundleImageDialog({
  required BuildContext context,
  required AdminBundleCubit cubit,
  required AdminBundle bundle,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => CategoryImageDialog(
      currentImageUrl: bundle.imageUrl,
      onApply: (source) async {
        if (source.isLink) {
          await cubit.updateBundleImage(bundle.id, source.url);
        } else {
          await cubit.uploadBundleImage(
            bundleId: bundle.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
      },
      onRemove: () async {
        await cubit.deleteBundleImageFile(bundle.imageUrl);
        await cubit.updateBundleImage(bundle.id, null);
      },
    ),
  );
}
