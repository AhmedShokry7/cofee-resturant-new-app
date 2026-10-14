import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/phone_auth_page_body.dart';

class PhoneAuthPage extends StatelessWidget {
  const PhoneAuthPage({super.key});

  static const routeName = "phoneAuthRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: BlocProvider(
        create: (context) => PhoneAuthCubit(context.read<AuthRepository>()),
        child: const PhoneAuthPageBody(),
      ),
    );
  }
}
