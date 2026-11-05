import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/profile/presentation/manager/account_details/account_details_cubit.dart';
import 'package:new_coffee/features/profile/presentation/views/widgets/edit_profile_view.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';

/// Your profile: the screen that reads the signed-in account and lets the
/// customer move their own name, phone and password.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  static const routeName = "editProfileRoute";

  @override
  Widget build(BuildContext context) {
    // Inside AuthGuard: the form reads and writes a real account, so a customer
    // who is not signed in never starts that read.
    return AuthGuard(
      child: BlocProvider(
        create: (context) =>
            AccountDetailsCubit(repository: context.read<AuthRepository>())
              ..load(),
        // Not const: a canonicalised instance would be handed to the same
        // element on every rebuild, so the form would keep the labels of the
        // language it first started in after the customer switches.
        child: EditProfileView(),
      ),
    );
  }
}
