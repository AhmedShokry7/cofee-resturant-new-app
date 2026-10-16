import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/session_repository.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

class OtpPageBody extends StatefulWidget {
  const OtpPageBody({super.key, required this.phone});

  final String phone;

  @override
  State<OtpPageBody> createState() => _OtpPageBodyState();
}

class _OtpPageBodyState extends State<OtpPageBody> {
  static const int _codeLength = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_code.length < _codeLength) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.enterSixDigitCode)));
      return;
    }
    context.read<PhoneAuthCubit>().verifyCode(phone: widget.phone, code: _code);
  }

  void _resend() {
    FocusScope.of(context).unfocus();
    context.read<PhoneAuthCubit>().sendCode(phone: widget.phone);
  }

  Future<void> _onAuthenticated() async {
    await const SessionRepository().markAuthenticated();
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(MainPage.routeName, (route) => false);
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
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(S.codeSent)));
            } else if (state is PhoneAuthSuccess) {
              _onAuthenticated();
            }
          },
          builder: (context, state) {
            final isLoading = state is PhoneAuthLoading;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AuthSpacings.top.h),
                Text(
                  S.verificationCode,
                  textAlign: TextAlign.center,
                  style: AppFonts.semiBold24(context),
                ),
                SizedBox(height: AuthSpacings.titleGap.h),
                Text(
                  "We sent a 6-digit code to ${widget.phone}",
                  textAlign: TextAlign.center,
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: AuthSpacings.headerGap.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _codeLength,
                    (index) => SizedBox(
                      width: 46.w,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        autofocus: index == 0,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        textInputAction: index == _codeLength - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(1),
                        ],
                        onChanged: (value) => _onChanged(value, index),
                        onFieldSubmitted: (_) {
                          if (index == _codeLength - 1) _submit();
                        },
                        style: AppFonts.semiBold18(context),
                        cursorColor: AppColor.primaryColor,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: SpacingTokens.md.h,
                          ),
                          filled: true,
                          fillColor: AppColor.lightGreyColor,
                          border: _border(),
                          enabledBorder: _border(),
                          focusedBorder: _border(color: AppColor.primaryColor),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AuthSpacings.fieldsGap.h),
                CustomBtn(
                  text: S.verify,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                SizedBox(height: AuthSpacings.sectionGap.h),
                AuthSwitchPrompt(
                  question: S.didntReceiveCode,
                  actionText: S.resend,
                  onTap: _resend,
                ),
                SizedBox(height: AuthSpacings.bottom.h),
              ],
            );
          },
        ),
      ),
    );
  }

  OutlineInputBorder _border({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: color ?? Colors.transparent),
    );
  }
}
