import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/email_auth_page_body.dart';

/// The first half of the e-mail code door: the customer says which mailbox.
class EmailAuthPage extends StatelessWidget {
  const EmailAuthPage({super.key});

  static const routeName = "emailAuthRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: BlocProvider(
        create: (context) => EmailAuthCubit(context.read<AuthRepository>()),
        child: const EmailAuthPageBody(),
      ),
    );
  }
}
