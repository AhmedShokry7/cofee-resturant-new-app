import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/forget_password_page.dart';
import 'package:new_coffee/features/auth/presentation/views/phone_auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/sign_up_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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

  /// Hands the customer over to wherever they were going.
  ///
  /// The [AuthCubit] already decided this (and wrote the session marker); only
  /// the *where* is resolved here, because it depends on the route this page
  /// was pushed with, which lives in the widget tree.
  void _onAuthenticated() {
    // Return to the page that asked for authentication when possible, instead
    // of always replacing it with the home page.
    final origin = ModalRoute.of(context)?.settings.arguments;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (origin is String && origin.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(origin);
    } else {
      _goToStore();
    }
  }

  void _onSkipped() => _goToStore();

  void _goToStore() {
    Navigator.of(context).pushReplacementNamed(MainPage.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
            } else if (state is AuthSkipped) {
              _onSkipped();
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return Stack(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: AuthSpacings.top),
                      Text(
                        S.signIn,
                        textAlign: TextAlign.center,
                        style: AppFonts.semiBold24(context),
                      ),
                      SizedBox(height: AuthSpacings.titleGap),
                      Text(
                        S.welcomeBackSubtitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.regular14(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(height: AuthSpacings.headerGap),
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
                      SizedBox(height: AuthSpacings.fieldsGap),
                      CustomBtn(
                        text: S.signIn,
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      SizedBox(height: AuthSpacings.buttonGap),
                      AuthSocialLogin(isLoading: isLoading),
                      SizedBox(height: AuthSpacings.sectionGap),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Material(
                            color: AppColor.whiteColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              side: BorderSide(color: AppColor.primaryColor),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () =>
                                  Navigator.of(context)
                                      .pushNamed(PhoneAuthPage.routeName),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSizes.px14,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.smartphone,
                                      size: AppSizes.px20,
                                      color: AppColor.primaryColor,
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Flexible(
                                      child: Text(
                                        S.continueWithPhone,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: AppFonts.regular14(context)
                                            .copyWith(
                                              color: AppColor.primaryColor,
                                              fontWeight: AppFontWeights.medium,
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
                      SizedBox(height: AuthSpacings.sectionGap),
                      AuthSwitchPrompt(
                        question: S.dontHaveAccount,
                        actionText: S.signUp,
                        onTap: () =>
                            Navigator.of(context)
                                .pushReplacementNamed(SignUpPage.routeName),
                      ),
                      SizedBox(height: AuthSpacings.bottom),
                    ],
                  ),
                ),
                // Last, so it wins the overlap: the form's title box is
                // stretched across the full width and reaches into the top-right
                // corner, where skipping lives.
                SkipBtn(
                  onTap: () => context.read<AuthCubit>().skipAuthentication(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
