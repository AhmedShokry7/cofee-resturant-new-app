import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// The square pick used on record cards for a bulk action.
///
/// It sits on the picture of the card, so it stays readable on every theme and
/// never competes with the card actions.
class AdminSelectionCheckBox extends StatelessWidget {
  const AdminSelectionCheckBox({super.key, required this.checked, this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: Material(
        color: AppColor.whiteColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppDimensions.recordFieldRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.recordFieldRadius),
          child: Container(
            width: AppDimensions.recordCheckBoxSize,
            height: AppDimensions.recordCheckBoxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppDimensions.recordFieldRadius,
              ),
              border: Border.all(
                color: checked ? AppColor.primaryColor : AppColor.greyColor,
              ),
            ),
            child: checked
                ? const Icon(
                    AppIcons.tick01,
                    size: 14,
                    color: AppColor.primaryColor,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
