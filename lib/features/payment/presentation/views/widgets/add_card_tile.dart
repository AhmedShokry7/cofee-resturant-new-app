import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
              AppIcons.creditCard,
              size: AppSpacing.xl,
              color: AppColor.greyColor,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                S.addCard,
                style: AppFonts.regular14(context)
                    .copyWith(color: AppColor.greyColor),
              ),
            ),
            Icon(AppIcons.add, size: AppSizes.px20, color: AppColor.greyColor),
          ],
        ),
      ),
    );
  }
}
