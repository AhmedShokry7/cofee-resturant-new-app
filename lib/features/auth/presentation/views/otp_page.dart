import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/otp_page_body.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key, required this.phone});

  static const routeName = "otpRoute";

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton()),
      body: BlocProvider(
        create: (context) => PhoneAuthCubit(context.read<AuthRepository>()),
        child: OtpPageBody(phone: phone),
      ),
    );
  }
}
