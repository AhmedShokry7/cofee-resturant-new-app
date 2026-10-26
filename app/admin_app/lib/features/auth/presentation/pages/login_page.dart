import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/widgets/login_screen.dart';

/// صفحة الدخول: تملك حقول النموذج وترسل أحداث المصادقة إلى البلوك.
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
      AuthSignInSubmitted(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured =
        AppConfig.isSupabaseConfigured && SupabaseService.isReady;

    return LoginScreen(
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      onSubmit: _submit,
      showConfigurationWarning: !configured,
    );
  }
}
