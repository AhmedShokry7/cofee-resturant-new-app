import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/password_reset/password_reset_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/reset_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

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
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xl.w),
        child: BlocConsumer<PasswordResetCubit, PasswordResetState>(
          listener: (context, state) {
            if (state is PasswordResetFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            } else if (state is PasswordResetEmailSent) {
              Navigator.of(context).pushNamed(ResetPasswordPage.routeName);
            }
          },
          builder: (context, state) {
            final isLoading = state is PasswordResetLoading;
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AuthSpacings.top.h),
                  Text(
                    "Forget Password",
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: AuthSpacings.titleGap.h),
                  Text(
                    "Enter your email and we'll send you a link to reset your password",
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AuthSpacings.headerGap.h),
                  CustomTextFormField(
                    controller: _emailController,
                    hint: "Email",
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: (value) => (value == null || value.isEmpty)
                        ? "Email is required"
                        : null,
                  ),
                  SizedBox(height: AuthSpacings.fieldsGap.h),
                  CustomBtn(
                    text: "Send Reset Link",
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  SizedBox(height: AuthSpacings.buttonGap.h),
                  AuthSwitchPrompt(
                    question: "Remember your password? ",
                    actionText: "Sign In",
                    onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      AuthPage.routeName,
                      (route) => false,
                    ),
                  ),
                  SizedBox(height: AuthSpacings.bottom.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
