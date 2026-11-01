import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class SelectionRadio extends StatelessWidget {
  const SelectionRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.xl,
      width: AppSpacing.xl,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColor.primaryColor : AppColor.borderColor,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                height: AppSizes.px14,
                width: AppSizes.px14,
                decoration: BoxDecoration(
                  color: AppColor.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
