import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Pill quantity stepper shared by the product details content.
///
/// Decrement/increment dispatch to the owning cubit; the displayed number
/// always mirrors the cubit's quantity, so there is exactly one quantity
/// state per screen.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.borderColor),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(AppIcons.minus),
            color: AppColor.primaryColor,
            iconSize: AppSizes.px18,
            padding: EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('$quantity', style: AppFonts.semiBold16(context)),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(AppIcons.add),
            color: AppColor.primaryColor,
            iconSize: AppSizes.px18,
            padding: EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
