import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/location/data/services/location_permission_service.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

class LoginPageBody extends StatefulWidget {
  const LoginPageBody({super.key});

  @override
  State<LoginPageBody> createState() => _LoginPageBodyState();
}

class _LoginPageBodyState extends State<LoginPageBody> {
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
    await const SessionRepository().markAuthenticated();
    if (!mounted) return;
    // Return to the page that asked for authentication when possible, instead
    // of always replacing it with the home page.
    final origin = ModalRoute.of(context)?.settings.arguments;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (origin is String && origin.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(origin);
    } else {
      Navigator.of(context).pushReplacementNamed(MainPage.routeName);
    }
    // The location prompt is asked for after the handover: it is a system
    // dialog, and waiting for it before navigating left the app on the login
    // screen until the customer answered it.
    unawaited(LocationPermissionService.requestOnFirstLaunch());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xl.w),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is AuthSuccess) {
              _onAuthenticated();
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return Stack(
              children: [
                SkipBtn(
                  onTap: () async {
                    await const SessionRepository().markAuthenticated();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed(MainPage.routeName);
                    unawaited(
                      LocationPermissionService.requestOnFirstLaunch(),
                    );
                  },
                ),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: AuthSpacings.top.h),
                      Text(
                        S.signIn,
                        textAlign: TextAlign.center,
                        style: AppFonts.semiBold24(context),
                      ),
                      SizedBox(height: AuthSpacings.titleGap.h),
                      Text(
                        S.welcomeBackSubtitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.regular14(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(height: AuthSpacings.headerGap.h),
                      CustomTextFormField(
                        controller: _emailController,
                        hint: S.emailHint,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value == null || value.isEmpty)
                            ? S.emailRequired
                            : null,
                      ),
                      CustomTextFormField(
                        controller: _passwordController,
                        hint: S.passwordHint,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) => (value == null || value.isEmpty)
                            ? S.passwordRequired
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(context)
                                  .pushNamed(ForgetPasswordPage.routeName),
                          child: Text(
                            S.forgotPasswordQ,
                            style: AppFonts.regular12(context).copyWith(
                              color: AppColor.primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AuthSpacings.fieldsGap.h),
                      CustomBtn(
                        text: S.signIn,
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      SizedBox(height: AuthSpacings.buttonGap.h),
                      AuthSocialLogin(isLoading: isLoading),
                      SizedBox(height: AuthSpacings.sectionGap.h),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Material(
                            color: AppColor.whiteColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100.r),
                              side: BorderSide(
                                color: AppColor.primaryColor,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.of(context)
                                      .pushNamed(PhoneAuthPage.routeName),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: SpacingTokens.lg.w,
                                  vertical: 14.h,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      HugeIcons.strokeRoundedSmartPhone01,
                                      size: 20.w,
                                      color: AppColor.primaryColor,
                                    ),
                                    SizedBox(width: SpacingTokens.sm.w),
                                    Flexible(
                                      child: Text(
                                        S.continueWithPhone,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: AppFonts.regular14(context)
                                            .copyWith(
                                              color: AppColor.primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AuthSpacings.sectionGap.h),
                      AuthSwitchPrompt(
                        question: S.dontHaveAccount,
                        actionText: S.signUp,
                        onTap: () =>
                            Navigator.of(context)
                                .pushReplacementNamed(SignUpPage.routeName),
                      ),
                      SizedBox(height: AuthSpacings.bottom.h),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
