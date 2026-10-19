import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/auth/presentation/manager/auth/auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_social_login.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/location/data/services/location_permission_service.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/shared/widgets/skip_btn.dart';

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
    await const SessionRepository().markAuthenticated();
    if (!mounted) return;
    await LocationPermissionService.requestOnFirstLaunch();
    if (!mounted) return;
    final origin = ModalRoute.of(context)?.settings.arguments;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (origin is String && origin.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(origin);
    } else {
      Navigator.of(context).pushReplacementNamed(MainPage.routeName);
    }
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
              final repo = context.read<AuthRepository>();
              final needsVerification = repo is SupabaseAuthRepository &&
                  repo.lastSignUpNeedsEmailConfirmation;
              if (needsVerification) {
                AuthMessageDialog.show(
                  context,
                  type: AuthMessageType.info,
                  message: S.signUpEmailVerification,
                );
              } else {
                _onAuthenticated();
              }
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
                    await LocationPermissionService.requestOnFirstLaunch();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed(MainPage.routeName);
                  },
                ),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: AuthSpacings.top.h),
                      Text(
                        S.signUp,
                        textAlign: TextAlign.center,
                        style: AppFonts.semiBold24(context),
                      ),
                      SizedBox(height: AuthSpacings.titleGap.h),
                      Text(
                        S.createAccountSubtitle,
                        textAlign: TextAlign.center,
                        style: AppFonts.regular14(context)
                            .copyWith(color: AppColor.greyColor),
                      ),
                      SizedBox(height: AuthSpacings.headerGap.h),
                      CustomTextFormField(
                        controller: _nameController,
                        hint: S.nameHint,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value == null || value.isEmpty)
                            ? S.nameRequired
                            : null,
                      ),
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
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value == null || value.isEmpty)
                            ? S.passwordRequired
                            : null,
                      ),
                      CustomTextFormField(
                        controller: _confirmPasswordController,
                        hint: S.confirmPasswordHint,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) =>
                            (value != _passwordController.text)
                            ? S.passwordsNoMatch
                            : null,
                      ),
                      SizedBox(height: AuthSpacings.fieldsGap.h),
                      CustomBtn(
                        text: S.signUp,
                        isLoading: isLoading,
                        onPressed: _submit,
                      ),
                      SizedBox(height: AuthSpacings.buttonGap.h),
                      AuthSocialLogin(label: S.orSignUpWith, isLoading: isLoading),
                      SizedBox(height: AuthSpacings.sectionGap.h),
                      AuthSwitchPrompt(
                        question: S.alreadyHaveAccount,
                        actionText: S.signIn,
                        onTap: () =>
                            Navigator.of(context)
                                .pushReplacementNamed(AuthPage.routeName),
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
