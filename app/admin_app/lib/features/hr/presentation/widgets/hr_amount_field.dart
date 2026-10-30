import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';
import 'package:flutter/material.dart';

/// حقل مبلغ: رقم فقط، وعلمة الريال داخل الحقل لا بجانبه نصًا.
///
/// لا يُطبع «ر.س» مع أي رقم في التطبيق، فالعملة رمز معروف؛ والمبلغ يُدخل
/// نيئا لأن القاعدة هي التي تدوّره وتحفظه في `numeric(12,2)`.
class HrAmountField extends StatelessWidget {
  const HrAmountField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.required = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(fontSize: AppFontSizes.size12_5),
      decoration:
          adminDialogFieldDecoration(
            context,
            label: label,
            hint: hint,
            required: required,
          ).copyWith(
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSizes.px10),
              child: const CurrencyIcon(size: AppSizes.px14),
            ),
            suffixIconConstraints: const BoxConstraints(),
          ),
    );
  }
}
