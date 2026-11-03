import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class PaymentOptionTile extends StatelessWidget {
  const PaymentOptionTile({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodModel method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: AppColor.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: Container(
            margin: EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              border: Border.all(color: AppColor.borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  method.icon,
                  size: AppSpacing.xl,
                  color: AppColor.greyColor,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    method.label,
                    style: AppFonts.medium16(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ),
                SelectionRadio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
