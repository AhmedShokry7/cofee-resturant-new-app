import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_page_body.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  static const routeName = "authRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider(
        create: (context) => AuthCubit(context.read<AuthRepository>()),
        child: const AuthPageBody(),
      ),
    );
  }
}
