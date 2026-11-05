import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

/// The two entries the customer confirmed, or null when the dialog was
/// dismissed or the fields failed validation.
typedef PasswordChange = ({String newPassword, String oldPassword});

/// Asks for the three password fields and hands back what to send.
///
/// It only collects and validates: the write belongs to whoever opened it, so a
/// dialog that reached the cubit itself could not be reused or tested without
/// one. The two new entries are compared against each other here because a
/// mismatch is a typing mistake, not a server answer.
Future<PasswordChange?> showChangePasswordDialog(BuildContext context) async {
  return showDialog<PasswordChange>(
    context: context,
    builder: (dialogContext) => _ChangePasswordDialog(
      onSubmit: (value) {
        Navigator.of(dialogContext).pop(value);
      },
    ),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.onSubmit});

  /// Closes the dialog with the collected pair. Left to the caller's navigator
  /// so the dialog never assumes how it was pushed.
  final void Function(PasswordChange change) onSubmit;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmit((
      oldPassword: _oldPasswordController.text.trim(),
      newPassword: _newPasswordController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.changePassword),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextFormField(
              controller: _oldPasswordController,
              hint: S.currentPasswordHint,
              icon: AppIcons.password,
              obscureText: true,
              validator: AuthFormRules.password,
            ),
            CustomTextFormField(
              controller: _newPasswordController,
              hint: S.newPasswordHint,
              icon: AppIcons.password,
              obscureText: true,
              validator: AuthFormRules.newPassword,
            ),
            CustomTextFormField(
              controller: _confirmPasswordController,
              hint: S.confirmPasswordHint,
              icon: AppIcons.password,
              obscureText: true,
              validator: (value) => AuthFormRules.confirmPassword(
                value,
                _newPasswordController.text,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(S.save)),
      ],
    );
  }
}
