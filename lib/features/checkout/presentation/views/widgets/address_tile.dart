import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';

class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final AddressModel address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SpacingTokens.md.h),
        child: Row(
          children: [
            Icon(
              HugeIcons.strokeRoundedLocation01,
              size: 24.w,
              color: selected ? AppColor.primaryColor : AppColor.greyColor,
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.label, style: AppFonts.semiBold16(context)),
                  SizedBox(height: 4.h),
                  Text(
                    address.details,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                ],
              ),
            ),
            SizedBox(width: SpacingTokens.md.w),
            SelectionRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}
