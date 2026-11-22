import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/location/data/services/location_permission_service.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/welcome/presentation/manager/welcome/welcome_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_page_body.dart';

/// The first screen a brand new customer sees.
///
/// It owns the cubit and the two reactions the cubit asks for: replacing itself
/// with the next screen, and saying so when nothing could be stored. Every
/// decision behind those reactions lives in [WelcomeCubit].
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  static const routeName = "welcomeView";

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
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
    return BlocProvider(
      create: (context) => WelcomeCubit(),
      child: BlocListener<WelcomeCubit, WelcomeState>(
        listener: (context, state) {
          final nextRoute = state.nextRoute;
          if (nextRoute != null) {
            Navigator.of(context).pushReplacementNamed(nextRoute);
            return;
          }
          if (state.saveFailed) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(S.tryAgainLater)));
          }
        },
        child: const Scaffold(body: WelcomePageBody()),
      ),
    );
  }
}
