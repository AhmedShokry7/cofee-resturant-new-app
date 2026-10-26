import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';

/// Shows the failure of an action to the admin, replacing the last message.
void showErrorSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColor.errorColor),
  );
}

/// Asks the admin to confirm a deletion, and runs it when the action is
/// pressed.
void showConfirmDeleteSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onConfirm,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: S.delete,
        textColor: AppColor.whiteColor,
        onPressed: onConfirm,
      ),
    ),
  );
}

/// The confirmation text of a deletion, in the language of the panel.
String deleteConfirmationText(String nameAr, String nameEn) {
  return AppLocale.instance.isArabic
      ? 'هل تريد حذف "$nameAr"؟'
      : 'Do you want to delete "$nameEn"?';
}

/// Asks the admin to confirm a bulk deletion, runs it, then reports how many
/// records went and how many stayed selected after a failure.
Future<void> confirmBulkDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<({int deleted, int failed})> Function() onDelete,
  required String Function(int deleted) deletedMessage,
  required String Function(int failed) partialMessage,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColor.errorColor,
            foregroundColor: AppColor.whiteColor,
          ),
          child: Text(S.delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final outcome = await onDelete();
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  if (outcome.failed == 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(deletedMessage(outcome.deleted))),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(partialMessage(outcome.failed)),
        backgroundColor: AppColor.errorColor,
      ),
    );
  }
}
