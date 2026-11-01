import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/welcome/presentation/manager/welcome/welcome_cubit.dart';
import 'package:new_coffee/features/welcome/presentation/views/widgets/welcome_page_body.dart';

/// The first screen a brand new customer sees.
///
/// It owns the cubit and the two reactions the cubit asks for: replacing itself
/// with the next screen, and saying so when nothing could be stored. Every
/// decision behind those reactions lives in [WelcomeCubit].
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const routeName = "welcomeView";

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
