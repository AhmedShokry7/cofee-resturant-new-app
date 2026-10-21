import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

/// Asks the staff member to confirm the sign out.
///
/// The dialog only reports the answer; the authentication call stays in the
/// shell that owns the session.
Future<bool> showAdminSignOutDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(S.signOutTitle),
      content: Text(S.signOutMessage),
      actions: [
        CustomBtn(
          text: S.cancel,
          onPressed: () => Navigator.of(context).pop(false),
          variant: BtnVariant.outlined,
          height: AppDimensions.dialogButtonHeight,
        ),
        CustomBtn(
          text: S.signOutTitle,
          onPressed: () => Navigator.of(context).pop(true),
          variant: BtnVariant.destructive,
          height: AppDimensions.dialogButtonHeight,
        ),
      ],
    ),
  );

  return result == true;
}
