import 'package:flutter/material.dart';

import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Activates or deactivates a bundle, and reports a failure to the admin.
Future<void> toggleBundleActive(
  BuildContext context,
  AdminBundleCubit cubit,
  AdminBundle bundle,
) async {
  try {
    await cubit.toggleActive(bundle);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(context, '$error');
  }
}

/// Asks the admin to confirm the deletion of a bundle, then deletes it.
void confirmDeleteBundle(
  BuildContext context,
  AdminBundleCubit cubit,
  AdminBundle bundle,
) {
  showConfirmDeleteSnackBar(
    context,
    message: deleteConfirmationText(bundle.nameAr, bundle.nameEn),
    onConfirm: () async {
      try {
        await cubit.deleteBundle(bundle.id);
      } catch (error) {
        if (!context.mounted) return;
        showErrorSnackBar(context, '$error');
      }
    },
  );
}
