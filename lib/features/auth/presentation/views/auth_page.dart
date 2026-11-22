import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/location/data/services/location_permission_service.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/login_page_body.dart';
import 'package:new_coffee/shared/widgets/design_page_sections.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  static const routeName = "authRoute";

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_requestFirstLaunchPermissions());
    });
  }

  Future<void> _requestFirstLaunchPermissions() async {
    await LocationPermissionService.requestOnFirstLaunch();
    await PushService.requestPermissionOnFirstLaunch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesignPageSectionsAbove(
        pageId: 'auth',
        child: BlocProvider(
          create: (context) => AuthCubit(context.read<AuthRepository>()),
          child: const LoginPageBody(),
        ),
      ),
    );
  }
}
