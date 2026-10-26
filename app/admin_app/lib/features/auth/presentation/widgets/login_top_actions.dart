import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/admin_language_button.dart';
import 'package:admin_app/shared/widgets/admin_theme_button.dart';

/// أزرار تبديل اللغة والمظهر فوق شاشة الدخول.
class LoginTopActions extends StatelessWidget {
  const LoginTopActions({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminLanguageButton(),
        SizedBox(width: AppDimensions.sm),
        AdminThemeButton(),
      ],
    );
  }
}
