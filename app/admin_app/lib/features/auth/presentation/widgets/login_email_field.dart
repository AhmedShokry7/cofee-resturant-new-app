import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/app_validators.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// حقل البريد الإلكتروني في نموذج الدخول.
class LoginEmailField extends StatelessWidget {
  const LoginEmailField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return CustomTextFormField(
      controller: controller,
      hint: S.emailHint,
      label: S.email,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      prefixIcon: const AppIcon(AppIcons.email),
      validator: AppValidators.email,
      bottomPadding: 0,
    );
  }
}
