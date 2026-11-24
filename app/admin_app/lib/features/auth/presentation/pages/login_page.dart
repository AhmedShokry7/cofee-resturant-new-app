import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/config/app_config.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:admin_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:admin_app/features/auth/presentation/models/invitation_link.dart';
import 'package:admin_app/features/auth/presentation/services/invitation_link_dispatcher.dart';
import 'package:admin_app/features/auth/presentation/widgets/invitation_accept_dialog.dart';
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
  final _linkDispatcher = InvitationLinkDispatcher.instance;
  int? _handledLinkId;

  @override
  void initState() {
    super.initState();
    _linkDispatcher.events.addListener(_onInvitationLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onInvitationLink());
  }

  @override
  void dispose() {
    _linkDispatcher.events.removeListener(_onInvitationLink);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onInvitationLink() {
    final event = _linkDispatcher.events.value;
    if (!mounted || event == null || event.id == _handledLinkId) return;
    _handledLinkId = event.id;
    final token = InvitationLink.tokenFromUri(event.uri);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final credentials = await showInvitationAcceptDialog(
        context,
        initialToken: token,
        invalidLink: token == null,
      );
      if (!mounted) return;
      _linkDispatcher.acknowledge(event.id);
      _linkDispatcher.replaceBrowserUrl(
        InvitationLink.withoutInviteParameter(Uri.base),
      );
      if (credentials == null) return;
      _emailController.text = credentials.email;
      _passwordController.text = credentials.password;
      _submit();
    });
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
