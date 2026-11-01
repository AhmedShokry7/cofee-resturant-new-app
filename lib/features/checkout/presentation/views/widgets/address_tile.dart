import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/addresses/data/model/address_model.dart';
import 'package:new_coffee/shared/widgets/selection_radio.dart';
import 'package:new_coffee/core/theme/tokens.dart';

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
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              AppIcons.location,
              size: AppSpacing.xl,
              color: selected ? AppColor.primaryColor : AppColor.greyColor,
            ),
            SizedBox(width: AppSpacing.md),
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
                        SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            S.defaultAddress,
                            style: AppFonts.regular12(context)
                                .copyWith(color: AppColor.primaryColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    address.details,
                    style: AppFonts.regular14(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                  if (!address.isDefault && onSetDefault != null) ...[
                    SizedBox(height: AppSpacing.xs),
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
            SizedBox(width: AppSpacing.md),
            if (onEdit != null)
              IconButton(icon: const Icon(AppIcons.edit), onPressed: onEdit),
            if (onDelete != null)
              IconButton(
                icon: const Icon(AppIcons.delete),
                onPressed: onDelete,
              ),
            SelectionRadio(selected: selected),
          ],
        ),
      ),
    );
  }
}
