import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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

  /// Hands the customer over to wherever they were going.
  ///
  /// The [AuthCubit] already decided this (and wrote the session marker); only
  /// the *where* is resolved here, because it depends on the route this page
  /// was pushed with, which lives in the widget tree.
  void _onAuthenticated() {
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
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthFailure) {
                  AuthMessageDialog.show(
                    context,
                    type: AuthMessageType.error,
                    message: state.message,
                  );
                } else if (state is AuthEmailConfirmationRequired) {
                  AuthMessageDialog.show(
                    context,
                    type: AuthMessageType.info,
                    message: S.signUpEmailVerification,
                  );
                } else if (state is AuthSuccess) {
                  _onAuthenticated();
                } else if (state is AuthSkipped) {
                  _onSkipped();
                }
              },
              builder: (context, state) {
                final isLoading = state is AuthLoading;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The pinned skip control owns this band.
                      const SizedBox(height: AppDimensions.skipReservedHeight),
                      Text(
                        S.signUp,
                        textAlign: TextAlign.center,
                        style: AppFonts.semiBold24(context),
                      ),
                      SizedBox(height: AuthSpacings.titleGap),
                      Text(
                        S.createAccountSubtitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.regular14(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(height: AuthSpacings.headerGap),
                      CustomTextFormField(
                        controller: _nameController,
                        hint: S.nameHint,
                        icon: AppIcons.user,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        validator: AuthFormRules.name,
                      ),
                      CustomTextFormField(
                        controller: _emailController,
                        hint: S.emailHint,
                        icon: AppIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: AuthFormRules.email,
                      ),
                      CustomTextFormField(
                        controller: _passwordController,
                        hint: S.passwordHint,
                        icon: AppIcons.lock,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: AuthFormRules.newPassword,
                      ),
                      CustomTextFormField(
                        controller: _confirmPasswordController,
                        hint: S.confirmPasswordHint,
                        icon: AppIcons.lock,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) => AuthFormRules.confirmPassword(
                          value,
                          _passwordController.text,
                        ),
                      ),
                      SizedBox(height: AuthSpacings.fieldsGap),
                      CustomBtn(
                        text: S.signUp,
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      SizedBox(height: AuthSpacings.buttonGap),
                      AuthSocialLogin(
                        label: S.orSignUpWith,
                        isLoading: isLoading,
                      ),
                      SizedBox(height: AuthSpacings.sectionGap),
                      AuthSwitchPrompt(
                        question: S.alreadyHaveAccount,
                        actionText: S.signIn,
                        // Forwarded so switching screens does not lose the page
                        // the customer was asked to authenticate for.
                        onTap: () => Navigator.of(context).pushReplacementNamed(
                          AuthPage.routeName,
                          arguments: ModalRoute.of(context)?.settings.arguments,
                        ),
                      ),
                      SizedBox(height: AuthSpacings.bottom),
                    ],
                  ),
                );
              },
            ),
          ),
          // The way out of the flow is pinned over the scroller, not inside it:
          // a skip control that scrolls off the top of a long form is no longer
          // a way out.
          SkipBtn(onTap: () => context.read<AuthCubit>().skipAuthentication()),
        ],
      ),
    );
  }
}
