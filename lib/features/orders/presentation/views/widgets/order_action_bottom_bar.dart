import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class OrderActionBottomBar extends StatelessWidget {
  const OrderActionBottomBar({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    this.cancelText,
    this.submitText,
  });

  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String? cancelText;
  final String? submitText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CustomBtn(
              text: cancelText ?? S.cancel,
              variant: BtnVariant.secondary,
              textColor: AppColor.primaryColor,
              onPressed: onCancel,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: CustomBtn(text: submitText ?? S.submit, onPressed: onSubmit),
          ),
        ],
      ),
    );
  }
}
