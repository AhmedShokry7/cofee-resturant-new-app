import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_state.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_message_banner.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';
import 'package:hugeicons/hugeicons.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
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
    return BlocBuilder<AdminAuthCubit, AdminAuthState>(
      builder: (context, state) {
        final isSubmitting = state.isSubmitting;

        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.staffSignIn,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                S.staffSignInSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (showConfigurationWarning) ...[
                const SizedBox(height: AppDimensions.lg),
                LoginMessageBanner(
                  color: AppColor.errorColor,
                  icon: HugeIcons.strokeRoundedCloudServer,
                  message: AppConfig.missingConfigurationMessage,
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: AppDimensions.lg),
                LoginMessageBanner(
                  color: AppColor.errorColor,
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  message: state.errorMessage!,
                ),
              ],
              const SizedBox(height: AppDimensions.xl),
              CustomTextFormField(
                controller: emailController,
                hint: 'you@example.com',
                label: S.email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(HugeIcons.strokeRoundedMail01),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return S.emailRequired;
                  if (!text.contains('@')) return S.validEmail;
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.lg),
              CustomTextFormField(
                controller: passwordController,
                hint: '*********',
                label: S.password,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                prefixIcon: const Icon(HugeIcons.strokeRoundedLock),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? HugeIcons.strokeRoundedViewOff
                        : HugeIcons.strokeRoundedView,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return S.passwordRequired;
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.xl),
              CustomBtn(
                text: S.signIn,
                onPressed: isSubmitting ? null : onSubmit,
                isLoading: isSubmitting,
                width: double.infinity,
                backgroundColor: AppColor.primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }
}
