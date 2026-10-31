import 'package:flutter/material.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Asks the admin to confirm deleting every selected bundle.
Future<void> confirmDeleteSelectedBundles(
  BuildContext context,
  AdminBundleCubit cubit,
) {
  final count = cubit.state.selectedCount;
  if (count == 0) return Future<void>.value();
  return confirmBulkDelete(
    context,
    title: S.deleteSelectedBundles,
    message: S.deleteBundlesConfirm(count),
    onDelete: cubit.deleteSelected,
    deletedMessage: S.bundlesDeleted,
    partialMessage: S.bundlesDeletePartial,
  );
}

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
    showErrorSnackBar(context, adminErrorMessage(error));
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
        showErrorSnackBar(context, adminErrorMessage(error));
      }
    },
  );
}
