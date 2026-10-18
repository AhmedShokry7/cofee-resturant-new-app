import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/payment/presentation/views/widgets/card_preview.dart';
import 'package:new_coffee/shared/utils/card_brand.dart';
import 'package:new_coffee/shared/utils/input_formatters.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/custom_text_form_field.dart';

class AddCardPage extends StatefulWidget {
  const AddCardPage({super.key});

  static const routeName = "addCardRoute";

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _saveCard = false;

  /// CVV digit count required by the detected card brand (3, or 4 for Amex).
  int _cvvLength = 3;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  /// Exact CVV digit count for the brand currently typed in the number
  /// field: 4 for American Express, 3 for every other brand.
  /// Mutates state, so the caller wraps it in a setState.
  void _syncCvvLength() {
    final digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    _cvvLength = digits.isNotEmpty && detectCardBrand(digits) == CardBrand.amex
        ? 4
        : 3;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    // Raw card data is never stored locally. Cards are tokenized and stored
    // by the payment provider only through the trusted checkout flow.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Cards are saved securely during checkout. No card data is stored on this device.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.addCard)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.lg.w,
            SpacingTokens.md.h,
            SpacingTokens.lg.w,
            SpacingTokens.lg.w,
          ),
          children: [
            CardPreview(
              number: _numberController.text,
              name: _nameController.text,
              expiry: _expiryController.text,
            ),
            SizedBox(height: SpacingTokens.xl.h),
            CustomTextFormField(
              controller: _nameController,
              hint: S.cardHolderName,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? S.cardHolderRequired
                  : null,
            ),
            CustomTextFormField(
              controller: _numberController,
              hint: S.cardNumber,
              keyboardType: TextInputType.number,
              inputFormatters: [CardNumberInputFormatter()],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(_syncCvvLength),
              validator: (value) =>
                  (value == null || value.replaceAll(' ', '').length < 16)
                  ? S.validCardNumber
                  : null,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextFormField(
                    controller: _expiryController,
                    hint: "MM/YY",
                    keyboardType: TextInputType.number,
                    inputFormatters: [ExpiryDateInputFormatter()],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: (value) => (value == null || value.length < 5)
                        ? S.invalidDate
                        : null,
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: CustomTextFormField(
                    controller: _cvvController,
                    hint: _cvvLength == 4 ? 'CVV (4 digits)' : 'CVV',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_cvvLength),
                    ],
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        (value == null || value.length != _cvvLength)
                        ? "CVV must be $_cvvLength digits"
                        : null,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _saveCard,
                  onChanged: (value) =>
                      setState(() => _saveCard = value ?? false),
                ),
                Text(
                  S.saveCard,
                  style: AppFonts.medium14(context)
                      .copyWith(color: AppColor.secondryColor),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        decoration: const BoxDecoration(
          color: AppColor.whiteColor,
          border: Border(top: BorderSide(color: AppColor.borderColor)),
        ),
        child: CustomBtn(text: S.addCard, onPressed: _submit),
      ),
    );
  }
}
