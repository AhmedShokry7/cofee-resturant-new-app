import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/email_otp_page_body.dart';

/// The second half of the e-mail code door: the customer types what the mail
/// carried.
class EmailOtpPage extends StatelessWidget {
  const EmailOtpPage({super.key, required this.email});

  static const routeName = "emailOtpRoute";

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: BlocProvider(
        create: (context) => EmailAuthCubit(context.read<AuthRepository>()),
        child: EmailOtpPageBody(email: email),
      ),
    );
  }
}
