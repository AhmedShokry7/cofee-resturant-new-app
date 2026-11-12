import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/payment_method_model.dart';
import 'package:new_coffee/core/theme/motion_tokens.dart';
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
      selected: selected,
      // A tap target without the InkWell wash: the ripple the transparent
      // Material paints under the tile read as a stained rectangle.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: MotionTokens.stateChange,
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            color: selected ? AppColor.primarySoft : AppColor.transparent,
            border: Border.all(
              color: selected ? AppColor.primaryColor : AppColor.borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                method.icon,
                size: AppSpacing.xl,
                color: selected ? AppColor.primaryColor : AppColor.greyColor,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  method.label,
                  style: AppFonts.medium16(context).copyWith(
                    color: selected
                        ? AppColor.primaryColor
                        : AppColor.textPrimary,
                  ),
                ),
              ),
              SelectionRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}
