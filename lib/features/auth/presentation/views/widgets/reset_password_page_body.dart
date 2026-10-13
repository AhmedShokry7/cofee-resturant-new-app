import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/password_reset/password_reset_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class ResetPasswordPageBody extends StatefulWidget {
  const ResetPasswordPageBody({super.key});

  @override
  State<ResetPasswordPageBody> createState() => _ResetPasswordPageBodyState();
}

class _ResetPasswordPageBodyState extends State<ResetPasswordPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<PasswordResetCubit>().resetPassword(
        password: _passwordController.text,
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
            } else if (state is PasswordResetSuccess) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AuthPage.routeName,
                (route) => false,
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
                  SizedBox(height: SpacingTokens.xl.h),
                  Text(
                    "Reset Password",
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: SpacingTokens.sm.h),
                  Text(
                    "Enter your new password below",
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: SpacingTokens.xxl.h),
                  CustomTextFormField(
                    controller: _passwordController,
                    hint: "New Password",
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value == null || value.isEmpty)
                        ? "Password is required"
                        : null,
                  ),
                  CustomTextFormField(
                    controller: _confirmPasswordController,
                    hint: "Confirm Password",
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => (value != _passwordController.text)
                        ? "Passwords do not match"
                        : null,
                  ),
                  SizedBox(height: SpacingTokens.lg.h),
                  CustomBtn(
                    text: "Reset Password",
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  SizedBox(height: SpacingTokens.xl.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
