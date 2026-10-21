import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_brand_panel.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_form.dart';
import 'package:admin_app/shared/widgets/admin_language_button.dart';
import 'package:admin_app/shared/widgets/admin_theme_button.dart';

class LoginPageBody extends StatelessWidget {
  const LoginPageBody({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.showConfigurationWarning,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final bool showConfigurationWarning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final form = LoginForm(
                formKey: formKey,
                emailController: emailController,
                passwordController: passwordController,
                obscurePassword: obscurePassword,
                onTogglePassword: onTogglePassword,
                onSubmit: onSubmit,
                showConfigurationWarning: showConfigurationWarning,
              );

              if (!isWide) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.pageHorizontalPadding,
                      vertical: AppDimensions.pageVerticalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.pageHorizontalPadding,
                            vertical: AppDimensions.pageVerticalPadding,
                          ),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  const Expanded(child: LoginBrandPanel()),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppDimensions.xxl),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppDimensions.xxl),
                              child: form,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          PositionedDirectional(
            top: AppDimensions.md,
            end: AppDimensions.md,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AdminLanguageButton(),
                const SizedBox(width: AppDimensions.sm),
                const AdminThemeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
