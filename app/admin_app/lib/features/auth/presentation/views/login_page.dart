import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/spacing_tokens.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const String routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AdminAuthCubit>().signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final configured = AppConfig.isSupabaseConfigured && SupabaseService.isReady;

    return Scaffold(
      backgroundColor: AppColor.lightGreyColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final form = _LoginForm(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onSubmit: _submit,
            showConfigurationWarning: !configured,
          );

          if (!isWide) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SpacingTokens.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(SpacingTokens.xl),
                      child: form,
                    ),
                  ),
                ),
              ),
            );
          }

          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 4,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(SpacingTokens.xxl),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(SpacingTokens.xxl),
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
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColor.secondryColor,
      padding: const EdgeInsets.all(SpacingTokens.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.local_cafe, color: Colors.white, size: 36),
          ),
          const SizedBox(height: SpacingTokens.xl),
          Text(
            'Coffee Admin',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: SpacingTokens.md),
          Text(
            'Manage orders, catalog, branches and staff in one place.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
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
                'Staff sign in',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: SpacingTokens.sm),
              Text(
                'Use your staff account to access the dashboard.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColor.greyColor,
                    ),
              ),
              if (showConfigurationWarning) ...[
                const SizedBox(height: SpacingTokens.lg),
                _MessageBanner(
                  color: AppColor.errorColor,
                  icon: Icons.settings_ethernet,
                  message: AppConfig.missingConfigurationMessage,
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: SpacingTokens.lg),
                _MessageBanner(
                  color: AppColor.errorColor,
                  icon: Icons.error_outline,
                  message: state.errorMessage!,
                ),
              ],
              const SizedBox(height: SpacingTokens.xl),
              TextFormField(
                controller: emailController,
                enabled: !isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Email is required.';
                  if (!text.contains('@')) return 'Enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: SpacingTokens.lg),
              TextFormField(
                controller: passwordController,
                enabled: !isSubmitting,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Password is required.';
                  return null;
                },
              ),
              const SizedBox(height: SpacingTokens.xl),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
