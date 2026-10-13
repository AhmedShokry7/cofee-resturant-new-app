import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';

class SelectionRadio extends StatelessWidget {
  const SelectionRadio({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24.w,
      width: 24.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColor.primaryColor : AppColor.borderColor,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                height: 14.w,
                width: 14.w,
                decoration: const BoxDecoration(
                  color: AppColor.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
