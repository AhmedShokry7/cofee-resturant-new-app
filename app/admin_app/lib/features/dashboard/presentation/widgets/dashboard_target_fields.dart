import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

/// حقل مبلغ الهدف وسطر رفضه، في حشوة واحدة.
///
/// الرفض المطبوع هنا هو ما ردّته القاعدة لا ما اختارته الواجهة: الحقل يملك
/// الكتابة فقط، ومن يقرّر أن الرقم مقبول أم لا هو منادي الحوار الذي يكتب فيها.
class DashboardTargetFields extends StatelessWidget {
  const DashboardTargetFields({
    super.key,
    required this.controller,
    required this.error,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextFormField(
            hint: S.dashboardTargetHint,
            label: S.dashboardTargetField,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: onSubmitted,
            suffixIcon: const CurrencyIcon(size: 15),
            bottomPadding: AppSpacing.xs,
          ),
          if (error != null) AdminInlineError(message: error!),
        ],
      ),
    );
  }
}
