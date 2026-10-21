import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/auth/presentation/manager/admin_auth_cubit.dart';
import 'package:admin_app/features/auth/presentation/manager/admin_auth_state.dart';
import 'package:admin_app/features/auth/presentation/pages/login_page.dart';
import 'package:admin_app/features/shell/presentation/views/admin_shell.dart';
import 'package:admin_app/features/startup/presentation/views/startup_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminAuthCubit, AdminAuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AdminAuthStatus.checking:
            return const StartupPage();
          case AdminAuthStatus.authenticated:
            final session = state.session;
            if (session == null) return const LoginPage();
            return AdminShell(session: session);
          case AdminAuthStatus.unauthenticated:
            return const LoginPage();
        }
      },
    );
  }
}
