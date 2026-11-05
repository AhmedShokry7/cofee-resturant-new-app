import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/settings_view.dart';

/// The account tab.
///
/// The customer's own name is read through [CurrentUserCubit] instead of a
/// future started inside this widget, so the tab that shows it and the tab that
/// edits it work on one read.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              CurrentUserCubit(repository: context.read<AuthRepository>())
                ..load(),
        ),
        // Signing out is an auth decision with a session marker behind it, so
        // it goes through AuthCubit instead of a second sign-out written here
        // against the repository.
        BlocProvider(
          create: (context) => AuthCubit(context.read<AuthRepository>()),
        ),
      ],
      // Not const: a canonicalised instance would be handed to the same
      // element on every rebuild, so the screen would keep the labels of the
      // language it first started in after the customer switches.
      child: SettingsView(),
    );
  }
}
