import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

/// The five lines of the account form and the two writes under them.
///
/// The fields are plain widgets here: the screen that owns the controllers
/// decides when they are filled, and this file only decides how they read. Both
/// name rules and the phone rule come from [AuthFormRules], so the number the
/// customer is asked for is the number the account can actually store.
class EditProfileForm extends StatelessWidget {
  const EditProfileForm({
    super.key,
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.isSaving,
    required this.isChangingPassword,
    required this.onSave,
    required this.onChangePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController email;
  final TextEditingController phone;
  final bool isSaving;
  final bool isChangingPassword;
  final VoidCallback onSave;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: AppLayout.pageBody,
        children: [
          CustomTextFormField(
            controller: firstName,
            hint: S.firstNameHint,
            icon: AppIcons.user,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            validator: AuthFormRules.name,
          ),
          CustomTextFormField(
            controller: lastName,
            hint: S.lastNameHint,
            icon: AppIcons.user,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          CustomTextFormField(
            controller: email,
            hint: S.emailHint,
            icon: AppIcons.mail,
            keyboardType: TextInputType.emailAddress,
            readOnly: true,
            helper: S.emailNotEditableHere,
            textInputAction: TextInputAction.none,
          ),
          CustomTextFormField(
            controller: phone,
            hint: S.phoneNumberHint,
            icon: AppIcons.smartphone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            // The shape is checked on the way in because the provider refuses
            // anything else with a message the customer cannot act on.
            validator: AuthFormRules.phone,
          ),
          SizedBox(height: AppSpacing.lg),
          CustomBtn(text: S.save, isLoading: isSaving, onPressed: onSave),
          SizedBox(height: AppSpacing.md),
          CustomBtn(
            text: S.changePassword,
            variant: BtnVariant.outlined,
            isLoading: isChangingPassword,
            onPressed: onChangePassword,
          ),
        ],
      ),
    );
  }
}
