import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/presentation/manager/password_reset/password_reset_cubit.dart';
import 'package:new_coffee/features/auth/presentation/views/auth_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: BlocConsumer<PasswordResetCubit, PasswordResetState>(
          listener: (context, state) {
            if (state is PasswordResetFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is PasswordResetSuccess) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AuthPage.routeName, (route) => false);
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
                    S.resetPassword,
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: AuthSpacings.titleGap),
                  Text(
                    S.enterNewPassword,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AuthSpacings.headerGap),
                  CustomTextFormField(
                    controller: _passwordController,
                    hint: S.newPasswordHint,
                    icon: AppIcons.password,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: AuthFormRules.newPassword,
                  ),
                  CustomTextFormField(
                    controller: _confirmPasswordController,
                    hint: S.confirmPasswordHint,
                    icon: AppIcons.password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) => AuthFormRules.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                  SizedBox(height: AuthSpacings.fieldsGap),
                  CustomBtn(
                    text: S.resetPassword,
                    isLoading: isLoading,
                    onPressed: _submit,
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
