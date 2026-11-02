import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/model/auth_form_rules.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/email_auth/email_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/email_otp_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class EmailAuthPageBody extends StatefulWidget {
  const EmailAuthPageBody({super.key});

  @override
  State<EmailAuthPageBody> createState() => _EmailAuthPageBodyState();
}

class _EmailAuthPageBodyState extends State<EmailAuthPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// The address in the shape the provider reads, or null while the field is
  /// not an address yet. [AuthFormRules] owns the rule because the code request
  /// and the verify call have to name the same address — asking for a code on
  /// one string and checking it against another is how a correct code fails.
  String? get _address {
    final text = _emailController.text.trim();
    return AuthFormRules.email(text) == null ? text : null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    final email = _address;
    if (!isValid || email == null) return;
    context.read<EmailAuthCubit>().sendCode(email: email);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: BlocConsumer<EmailAuthCubit, EmailAuthState>(
          listener: (context, state) {
            if (state is EmailAuthFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is EmailAuthCodeSent) {
              Navigator.of(context).pushNamed(
                EmailOtpPage.routeName,
                // The normalised address, so the code screen can say where the
                // mail went and the verify call repeats the same request body.
                arguments: _address ?? _emailController.text.trim(),
              );
              context.read<EmailAuthCubit>().reset();
            }
          },
          builder: (context, state) {
            final isLoading = state is EmailAuthLoading;
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AuthSpacings.top),
                  Text(
                    S.signInWithEmailCode,
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: AuthSpacings.titleGap),
                  Text(
                    S.emailAuthSubtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AuthSpacings.headerGap),
                  CustomTextFormField(
                    controller: _emailController,
                    hint: S.emailHint,
                    icon: AppIcons.mail,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: AuthFormRules.email,
                  ),
                  SizedBox(height: AuthSpacings.fieldsGap),
                  CustomBtn(
                    text: S.sendCode,
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
