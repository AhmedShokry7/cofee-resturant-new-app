import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_brand_panel.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_form.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_top_actions.dart';

/// هيكل شاشة الدخول: لوحة العلامة على الشاشات الواسعة، والبطاقة وحدها على
/// الشاشات الضيقة.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
    required this.showConfigurationWarning,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
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
              final wide =
                  constraints.maxWidth >= AppDimensions.loginWideBreakpoint;
              if (!wide) return _formPane(wide: false);

              return Row(
                children: [
                  const Expanded(child: LoginBrandPanel()),
                  Expanded(child: _formPane(wide: true)),
                ],
              );
            },
          ),
          const PositionedDirectional(
            top: AppDimensions.md,
            end: AppDimensions.md,
            child: LoginTopActions(),
          ),
        ],
      ),
    );
  }

  Widget _formPane({required bool wide}) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: wide
              ? AppDimensions.xxl
              : AppDimensions.pageHorizontalPadding,
          vertical: wide
              ? AppDimensions.xxl
              : AppDimensions.pageVerticalPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.formMaxWidth,
          ),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(
                wide ? AppDimensions.xxl : AppDimensions.xl,
              ),
              child: LoginForm(
                formKey: formKey,
                emailController: emailController,
                passwordController: passwordController,
                onSubmit: onSubmit,
                showConfigurationWarning: showConfigurationWarning,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
