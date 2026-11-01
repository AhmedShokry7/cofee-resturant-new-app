import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/password_reset/password_reset_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ForgetPasswordPageBody extends StatefulWidget {
  const ForgetPasswordPageBody({super.key});

  @override
  State<ForgetPasswordPageBody> createState() => _ForgetPasswordPageBodyState();
}

class _ForgetPasswordPageBodyState extends State<ForgetPasswordPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<PasswordResetCubit>().sendEmail(
        email: _emailController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: BlocConsumer<PasswordResetCubit, PasswordResetState>(
          listener: (context, state) {
            if (state is PasswordResetFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is PasswordResetEmailSent) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.info,
                message: S.passwordResetEmailSent,
                onAction: () =>
                    Navigator.of(context)
                        .pushNamed(ResetPasswordPage.routeName),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is PasswordResetLoading;
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AuthSpacings.top),
                  Text(
                    S.forgetPassword,
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: AuthSpacings.titleGap),
                  Text(
                    S.forgotPasswordSubtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AuthSpacings.headerGap),
                  CustomTextFormField(
                    controller: _emailController,
                    hint: S.emailHint,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: (value) => (value == null || value.isEmpty)
                        ? S.emailRequired
                        : null,
                  ),
                  SizedBox(height: AuthSpacings.fieldsGap),
                  CustomBtn(
                    text: S.sendResetLink,
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  SizedBox(height: AuthSpacings.buttonGap),
                  AuthSwitchPrompt(
                    question: S.rememberPasswordQ,
                    actionText: S.signIn,
                    onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      AuthPage.routeName,
                      (route) => false,
                    ),
                  ),
                  SizedBox(height: AuthSpacings.bottom),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
