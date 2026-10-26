import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/error/failure.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_email_field.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_heading.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_password_field.dart';
import 'package:admin_app/shared/widgets/admin_error_banner.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

/// نموذج الدخول: يعرض الحقول والأخطاء ويرسل الأحداث إلى [AuthBloc].
class LoginForm extends StatelessWidget {
  const LoginForm({
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
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final signedOut = state is AuthSignedOut
            ? state
            : const AuthSignedOut();
        final failure = signedOut.failure;

        return Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoginHeading(),
              if (showConfigurationWarning) ...[
                const SizedBox(height: AppDimensions.lg),
                AdminErrorBanner(
                  message: S.supabaseNotConfigured,
                  icon: AppIcons.server,
                ),
              ],
              if (failure != null) ...[
                const SizedBox(height: AppDimensions.lg),
                AdminErrorBanner(
                  message: _messageFor(failure),
                  icon: AppIcons.alert,
                ),
              ],
              const SizedBox(height: AppDimensions.xl),
              LoginEmailField(controller: emailController),
              const SizedBox(height: AppDimensions.lg),
              LoginPasswordField(
                controller: passwordController,
                obscurePassword: signedOut.obscurePassword,
                onToggleVisibility: () => context.read<AuthBloc>().add(
                  const AuthPasswordVisibilityToggled(),
                ),
                onSubmitted: onSubmit,
              ),
              const SizedBox(height: AppDimensions.xl),
              CustomBtn(
                text: S.signIn,
                onPressed: signedOut.isSubmitting ? null : onSubmit,
                isLoading: signedOut.isSubmitting,
                width: double.infinity,
                backgroundColor: scheme.primary,
                textColor: scheme.onPrimary,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// يختار نص الخطأ المعروض حسب نوع الفشل القادم من الطبقة الداخلية.
String _messageFor(Failure failure) => switch (failure) {
  InvalidCredentialsFailure() => S.invalidCredentials,
  NotActiveStaffFailure() => S.notActiveStaff,
  ConfigurationFailure() => S.supabaseNotConfigured,
  UnknownFailure() => S.unableToSignIn,
};
