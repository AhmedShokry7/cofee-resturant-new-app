import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:admin_app/features/auth/presentation/pages/login_page.dart';
import 'package:admin_app/features/shell/presentation/views/admin_shell.dart';
import 'package:admin_app/features/startup/presentation/views/startup_page.dart';
import 'package:admin_app/features/auth/presentation/services/invitation_link_dispatcher.dart';

/// يعرض شاشة البداية أثناء فحص الجلسة، ثم لوحة التحكم أو شاشة الدخول.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _linkDispatcher = InvitationLinkDispatcher.instance;

  @override
  void initState() {
    super.initState();
    _linkDispatcher.events.addListener(_handleInvitationLink);
  }

  @override
  void dispose() {
    _linkDispatcher.events.removeListener(_handleInvitationLink);
    super.dispose();
  }

  void _handleInvitationLink() {
    if (_linkDispatcher.events.value == null) return;
    final auth = context.read<AuthBloc>();
    if (auth.state is AuthSignedIn) {
      auth.add(const AuthSignOutRequested());
    }
  }

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
