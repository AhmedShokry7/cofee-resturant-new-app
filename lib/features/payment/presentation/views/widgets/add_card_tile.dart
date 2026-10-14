import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

class AddCardTile extends StatelessWidget {
  const AddCardTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.md.w,
          vertical: SpacingTokens.md.h,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: Row(
          children: [
            Icon(
              HugeIcons.strokeRoundedCreditCard,
              size: 24.w,
              color: AppColor.greyColor,
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Text(
                "Add Card",
                style: AppFonts.regular14(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
            ),
            Icon(
              HugeIcons.strokeRoundedAdd01,
              size: 20.w,
              color: AppColor.greyColor,
            ),
          ],
        ),
      ),
    );
  }
}

