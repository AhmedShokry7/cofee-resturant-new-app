import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

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
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
            color: AppColor.primaryColor,
            iconSize: 18.w,
            padding: EdgeInsets.all(SpacingTokens.xs.w),
            constraints: const BoxConstraints(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xs.w),
            child: Text('$quantity', style: AppFonts.semiBold16(context)),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
            color: AppColor.primaryColor,
            iconSize: 18.w,
            padding: EdgeInsets.all(SpacingTokens.xs.w),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
