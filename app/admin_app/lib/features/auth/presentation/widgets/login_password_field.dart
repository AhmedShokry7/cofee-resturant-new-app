import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/app_validators.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// حقل كلمة المرور مع زر إظهارها أو إخفائها.
class LoginPasswordField extends StatelessWidget {
  const LoginPasswordField({
    super.key,
    required this.controller,
    required this.obscurePassword,
    required this.onToggleVisibility,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomTextFormField(
      controller: controller,
      hint: S.passwordHint,
      label: S.password,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      prefixIcon: const AppIcon(AppIcons.passwordKey),
      suffixIcon: IconButton(
        tooltip: obscurePassword ? S.showPassword : S.hidePassword,
        onPressed: onToggleVisibility,
        icon: AppIcon(
          obscurePassword ? AppIcons.eyeOff : AppIcons.eye,
          color: theme.colorScheme.onSurfaceVariant,
          size: AppDimensions.fieldIconSize,
        ),
      ),
      validator: AppValidators.password,
      onFieldSubmitted: (_) => onSubmitted(),
      bottomPadding: 0,
    );
  }
}
