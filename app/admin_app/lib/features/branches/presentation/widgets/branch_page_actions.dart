import 'package:flutter/material.dart';

import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/presentation/manager/admin_branch_cubit.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Activates or deactivates a branch, and reports a failure to the admin.
Future<void> toggleBranchActive(
  BuildContext context,
  AdminBranchCubit cubit,
  AdminBranch branch,
) async {
  try {
    await cubit.toggleActive(branch);
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnackBar(context, '$error');
  }
}

/// Asks the admin to confirm the deletion of a branch, then deletes it.
void confirmDeleteBranch(
  BuildContext context,
  AdminBranchCubit cubit,
  AdminBranch branch,
) {
  showConfirmDeleteSnackBar(
    context,
    message: deleteConfirmationText(branch.nameAr, branch.nameEn),
    onConfirm: () async {
      try {
        await cubit.deleteBranch(branch.id);
      } catch (error) {
        if (!context.mounted) return;
        showErrorSnackBar(context, '$error');
      }
    },
  );
}
