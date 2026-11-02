import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/otp_code_input.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class OtpPageBody extends StatefulWidget {
  const OtpPageBody({super.key, required this.phone});

  final String phone;

  @override
  State<OtpPageBody> createState() => _OtpPageBodyState();
}

class _OtpPageBodyState extends State<OtpPageBody> {
  final OtpCodeController _code = OtpCodeController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_code.code.length < _code.length) {
      AuthMessageDialog.show(
        context,
        type: AuthMessageType.error,
        message: S.enterSixDigitCode,
      );
      return;
    }
    context.read<PhoneAuthCubit>().verifyCode(
      phone: widget.phone,
      code: _code.code,
    );
  }

  void _resend() {
    FocusScope.of(context).unfocus();
    // The code that is about to be replaced is already in the boxes. Leaving it
    // there lets the customer press Verify against a code the server stopped
    // accepting.
    _code.clear();
    _code.focusNodes.first.requestFocus();
    setState(() {});
    context.read<PhoneAuthCubit>().sendCode(phone: widget.phone);
  }

  /// The [PhoneAuthCubit] already wrote and confirmed the session marker, so
  /// this only performs the handover: the customer who signed in by phone
  /// starts a fresh stack at the store.
  void _onAuthenticated() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(MainPage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
          listener: (context, state) {
            if (state is PhoneAuthFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is PhoneAuthCodeSent) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.info,
                message: S.codeSent,
              );
            } else if (state is PhoneAuthSuccess) {
              _onAuthenticated();
            }
          },
          builder: (context, state) {
            final isLoading = state is PhoneAuthLoading;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AuthSpacings.top),
                Text(
                  S.verificationCode,
                  textAlign: TextAlign.center,
                  style: AppFonts.semiBold24(context),
                ),
                SizedBox(height: AuthSpacings.titleGap),
                Text(
                  S.otpSentTo(widget.phone),
                  textAlign: TextAlign.center,
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: AuthSpacings.headerGap),
                OtpCodeInput(controller: _code, onSubmitted: (_) => _submit()),
                SizedBox(height: AuthSpacings.fieldsGap),
                CustomBtn(
                  text: S.verify,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                SizedBox(height: AuthSpacings.sectionGap),
                AuthSwitchPrompt(
                  question: S.didntReceiveCode,
                  actionText: S.resend,
                  onTap: _resend,
                ),
                SizedBox(height: AuthSpacings.bottom),
              ],
            );
          },
        ),
      ),
    );
  }
}
