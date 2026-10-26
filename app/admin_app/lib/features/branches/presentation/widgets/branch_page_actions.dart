import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/branches/presentation/widgets/branch_format.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Confirms hiding an active branch before it stops receiving orders.
Future<bool> confirmBranchDeactivation(
  BuildContext context,
  AdminBranch branch,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _BranchConfirmDialog(
      title: S.branchDeactivateTitle,
      message: S.branchDeactivateConfirm(branchName(branch)),
      confirmLabel: S.branchDeactivate,
      confirmColor: AppColor.adminWarning,
    ),
  );
  return confirmed == true;
}

/// Confirms deleting a branch that carries no operational history.
Future<bool> confirmBranchDeletion(
  BuildContext context,
  AdminBranch branch,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _BranchConfirmDialog(
      title: S.branchDeleteTitle,
      message: deleteConfirmationText(branch.nameAr, branch.nameEn),
      confirmLabel: S.delete,
      confirmColor: AppColor.errorColor,
    ),
  );
  return confirmed == true;
}

class _BranchConfirmDialog extends StatelessWidget {
  const _BranchConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppFontSizes.size15,
          fontWeight: AppFontWeights.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: AppFontSizes.size11_5,
          height: AppTextHeights.line1_6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
        ),
      ],
    );
  }
}
