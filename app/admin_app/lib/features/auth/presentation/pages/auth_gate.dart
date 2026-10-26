import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:admin_app/features/auth/presentation/pages/login_page.dart';
import 'package:admin_app/features/shell/presentation/views/admin_shell.dart';
import 'package:admin_app/features/startup/presentation/views/startup_page.dart';

/// يعرض شاشة البداية أثناء فحص الجلسة، ثم لوحة التحكم أو شاشة الدخول.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => switch (state) {
        AuthChecking() => const StartupPage(),
        AuthSignedIn(:final session) => AdminShell(session: session),
        AuthSignedOut() => const LoginPage(),
      },
    );
  }
}
