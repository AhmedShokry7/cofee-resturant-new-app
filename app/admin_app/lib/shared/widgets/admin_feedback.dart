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
