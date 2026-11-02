import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/otp_code_input.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class EmailOtpPageBody extends StatefulWidget {
  const EmailOtpPageBody({super.key, required this.email});

  final String email;

  @override
  State<EmailOtpPageBody> createState() => _EmailOtpPageBodyState();
}

class _EmailOtpPageBodyState extends State<EmailOtpPageBody> {
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
    context.read<EmailAuthCubit>().verifyCode(
      email: widget.email,
      code: _code.code,
    );
  }

  void _resend() {
    FocusScope.of(context).unfocus();
    // The code that is about to be replaced is already in the boxes, and the
    // server has stopped accepting it the moment a new one was asked for.
    _code.clear();
    _code.focusNodes.first.requestFocus();
    setState(() {});
    context.read<EmailAuthCubit>().sendCode(email: widget.email);
  }

  /// The [EmailAuthCubit] already wrote and confirmed the session marker, so
  /// this only performs the handover: the customer who signed in by mail starts
  /// a fresh stack at the store.
  void _onAuthenticated() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(MainPage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: BlocConsumer<EmailAuthCubit, EmailAuthState>(
          listener: (context, state) {
            if (state is EmailAuthFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is EmailAuthCodeSent) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.info,
                message: S.codeSent,
              );
            } else if (state is EmailAuthSuccess) {
              _onAuthenticated();
            }
          },
          builder: (context, state) {
            final isLoading = state is EmailAuthLoading;
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
                  S.emailOtpSentTo(widget.email),
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
