import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/otp_page.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class PhoneAuthPageBody extends StatefulWidget {
  const PhoneAuthPageBody({super.key});

  @override
  State<PhoneAuthPageBody> createState() => _PhoneAuthPageBodyState();
}

class _PhoneAuthPageBodyState extends State<PhoneAuthPageBody> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (phone.isEmpty) return S.phoneRequired;
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone)) {
      return S.validPhoneNumber;
    }
    return null;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      context.read<PhoneAuthCubit>().sendCode(
        phone: _phoneController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xl.w),
        child: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
          listener: (context, state) {
            if (state is PhoneAuthFailure) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is PhoneAuthCodeSent) {
              Navigator.of(context).pushNamed(
                OtpPage.routeName,
                arguments: _phoneController.text.trim(),
              );
              context.read<PhoneAuthCubit>().reset();
            }
          },
          builder: (context, state) {
            final isLoading = state is PhoneAuthLoading;
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AuthSpacings.top.h),
                  Text(
                    S.signInWithPhone,
                    textAlign: TextAlign.center,
                    style: AppFonts.semiBold24(context),
                  ),
                  SizedBox(height: AuthSpacings.titleGap.h),
                  Text(
                    S.phoneAuthSubtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  SizedBox(height: AuthSpacings.headerGap.h),
                  CustomTextFormField(
                    controller: _phoneController,
                    hint: S.phoneHint,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                    ],
                    validator: _validatePhone,
                  ),
                  SizedBox(height: AuthSpacings.fieldsGap.h),
                  CustomBtn(
                    text: S.sendCode,
                    isLoading: isLoading,
                    onPressed: _submit,
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
