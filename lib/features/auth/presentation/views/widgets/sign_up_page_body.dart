import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/constant/app_constant.dart';
import 'package:new_coffee/core/services/shared_pref.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class SignUpPageBody extends StatefulWidget {
  const SignUpPageBody({super.key});

  @override
  State<SignUpPageBody> createState() => _SignUpPageBodyState();
}

class _SignUpPageBodyState extends State<SignUpPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signUp(
        name: _nameController.text.trim(),
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
                  SizedBox(height: AuthSpacings.top.h),
                  Text(
                    "Sign Up",
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: AuthSpacings.titleGap.h),
                  Text(
                    "Create your account to get started",
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AuthSpacings.headerGap.h),
                  CustomTextFormField(
                    controller: _nameController,
                    hint: "Name",
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? "Name is required" : null,
                  ),
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
                  SizedBox(height: AuthSpacings.fieldsGap.h),
                  CustomBtn(
                    text: "Sign Up",
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  SizedBox(height: AuthSpacings.buttonGap.h),
                  const AuthSocialLogin(label: "Or sign up with"),
                  SizedBox(height: AuthSpacings.sectionGap.h),
                  AuthSwitchPrompt(
                    question: "Already have an account? ",
                    actionText: "Sign In",
                    onTap: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(AuthPage.routeName),
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
