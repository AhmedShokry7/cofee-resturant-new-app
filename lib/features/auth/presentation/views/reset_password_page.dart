import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/password_reset/password_reset_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/reset_password_page_body.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  static const routeName = "resetPasswordRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: BlocProvider(
        create: (context) => PasswordResetCubit(context.read<AuthRepository>()),
        child: const ResetPasswordPageBody(),
      ),
    );
  }
}
