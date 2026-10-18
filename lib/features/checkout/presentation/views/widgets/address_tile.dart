import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/checkout/data/model/address_model.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';

class AddressTile extends StatelessWidget {
  const AddressTile({
    super.key,
    required this.address,
    required this.selected,
    required this.onTap,
    this.onSetDefault,
    this.onEdit,
    this.onDelete,
  });

  final AddressModel address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSetDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.label,
                          style: AppFonts.semiBold16(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (address.isDefault) ...[
                        SizedBox(width: 8.w),
                        Text(
                          S.defaultAddress,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.primaryColor),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    address.details,
                    style: AppFonts.regular14(
                      context,
                    ).copyWith(color: AppColor.greyColor),
                  ),
                  if (!address.isDefault && onSetDefault != null) ...[
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: onSetDefault,
                      child: Text(
                        S.setDefaultAddress,
                        style: AppFonts.regular12(context)
                            .copyWith(color: AppColor.primaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: SpacingTokens.md.w),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            SelectionRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}

