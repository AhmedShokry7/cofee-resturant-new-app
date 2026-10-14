import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class AuthPageBody extends StatefulWidget {
  const AuthPageBody({super.key});

  @override
  State<AuthPageBody> createState() => _AuthPageBodyState();
}

class _AuthPageBodyState extends State<AuthPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  Future<void> _onAuthenticated() async {
    await SharedPref.setValue(
      key: AppConstant.routesKey,
      value: AppConstant.homeRoute,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(MainPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xl.w),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            } else if (state is AuthSuccess) {
              _onAuthenticated();
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: SpacingTokens.lg.h),
                  Text(
                    "Sign In",
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: SpacingTokens.xs.h),
                  Text(
                    "Hi welcome back, you've been missed",
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: SpacingTokens.xl.h),
                  CustomTextFormField(
                    controller: _emailController,
                    hint: "Email",
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? "Email is required" : null,
                  ),
                  CustomTextFormField(
                    controller: _passwordController,
                    hint: "Password",
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => (value == null || value.isEmpty)
                        ? "Password is required"
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(ForgetPasswordPage.routeName),
                      child: Text(
                        "Forget your password?",
                        style: AppFonts.regular12(context).copyWith(
                          color: AppColor.primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: SpacingTokens.md.h),
                  CustomBtn(
                    text: "Sign In",
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  SizedBox(height: SpacingTokens.xl.h),
                  const AuthSocialLogin(),
                  SizedBox(height: SpacingTokens.lg.h),
                  CustomBtn(
                    text: "Continue with phone number",
                    variant: BtnVariant.outlined,
                    leadingIcon: Icon(
                      HugeIcons.strokeRoundedSmartPhone01,
                      size: 20.w,
                      color: AppColor.primaryColor,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(PhoneAuthPage.routeName),
                  ),
                  SizedBox(height: SpacingTokens.lg.h),
                  AuthSwitchPrompt(
                    question: "Don't have an account? ",
                    actionText: "Sign Up",
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(SignUpPage.routeName),
                  ),
                  SizedBox(height: SpacingTokens.lg.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
