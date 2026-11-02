import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_cubit.dart';
import 'package:new_coffee/features/auth/presentation/manager/phone_auth/phone_auth_state.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_spacings.dart';
import 'package:new_coffee/features/auth/presentation/views/widgets/auth_switch_prompt.dart';
import 'package:new_coffee/features/main/presentation/views/main_page.dart';
import 'package:new_coffee/shared/widgets/auth_message_dialog.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class OtpPageBody extends StatefulWidget {
  const OtpPageBody({super.key, required this.phone});

  final String phone;

  @override
  State<OtpPageBody> createState() => _OtpPageBodyState();
}

class _OtpPageBodyState extends State<OtpPageBody> {
  static const int _codeLength = 6;
  static const double _cellRadius = AppRadius.r12;

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
    if (value.length > 1) {
      // A paste, or the SMS suggestion, arrives in whichever cell is focused as
      // one string. Clipping every cell to a single character threw five of the
      // six digits away before the customer could see them, so the code that
      // was typed correctly still verified as wrong.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      // A whole code pasted into the third box still has to land, so a paste
      // that is long enough to be the entire code starts from the first box.
      final start = digits.length >= _codeLength ? 0 : index;
      for (
        var offset = 0;
        offset < digits.length && start + offset < _codeLength;
        offset++
      ) {
        _controllers[start + offset].text = digits[offset];
      }
      _focusNodes[(start + digits.length - 1).clamp(0, _codeLength - 1)]
          .requestFocus();
      setState(() {});
      return;
    }
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
      AuthMessageDialog.show(
        context,
        type: AuthMessageType.error,
        message: S.enterSixDigitCode,
      );
      return;
    }
    context.read<PhoneAuthCubit>().verifyCode(phone: widget.phone, code: _code);
  }

  void _resend() {
    FocusScope.of(context).unfocus();
    // The code that is about to be replaced is already in the boxes. Leaving it
    // there lets the customer press Verify against a code the server stopped
    // accepting.
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() {});
    context.read<PhoneAuthCubit>().sendCode(phone: widget.phone);
  }

  /// The [PhoneAuthCubit] already wrote and confirmed the session marker, so
  /// this only performs the handover: the customer who signed in by phone
  /// starts a fresh stack at the store.
  void _onAuthenticated() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(MainPage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: BlocConsumer<PhoneAuthCubit, PhoneAuthState>(
          listener: (context, state) {
            if (state is PhoneAuthFailure) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.error,
                message: state.message,
              );
            } else if (state is PhoneAuthCodeSent) {
              AuthMessageDialog.show(
                context,
                type: AuthMessageType.info,
                message: S.codeSent,
              );
            } else if (state is PhoneAuthSuccess) {
              _onAuthenticated();
            }
          },
          builder: (context, state) {
            final isLoading = state is PhoneAuthLoading;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: AuthSpacings.top),
                Text(
                  S.verificationCode,
                  textAlign: TextAlign.center,
                  style: AppFonts.semiBold24(context),
                ),
                SizedBox(height: AuthSpacings.titleGap),
                Text(
                  S.otpSentTo(widget.phone),
                  textAlign: TextAlign.center,
                  style: AppFonts.regular14(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: AuthSpacings.headerGap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _codeLength,
                    (index) => SizedBox(
                      width: AppSizes.px46,
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        autofocus: index == 0,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        // Only the first box is offered to the keyboard's code
                        // suggestion; `_onChanged` spreads whatever it hands
                        // over into the boxes after it.
                        autofillHints: index == 0
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                        textInputAction: index == _codeLength - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onChanged(value, index),
                        onFieldSubmitted: (_) {
                          if (index == _codeLength - 1) _submit();
                        },
                        style: AppFonts.semiBold18(context),
                        cursorColor: AppColor.primaryColor,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
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
                SizedBox(height: AuthSpacings.fieldsGap),
                CustomBtn(
                  text: S.verify,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                SizedBox(height: AuthSpacings.sectionGap),
                AuthSwitchPrompt(
                  question: S.didntReceiveCode,
                  actionText: S.resend,
                  onTap: _resend,
                ),
                SizedBox(height: AuthSpacings.bottom),
              ],
            );
          },
        ),
      ),
    );
  }

  OutlineInputBorder _border({Color? color}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(_cellRadius),
      borderSide: BorderSide(color: color ?? AppColor.transparent),
    );
  }
}
