import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';

/// The grab bar every bottom sheet opens with.
///
/// Four sheets drew this by hand with the same size and colour, so a change to
/// the handle meant finding all four.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      height: 4.h,
      width: 100.w,
      decoration: BoxDecoration(
        color: AppColor.borderColor,
        borderRadius: BorderRadius.circular(100),
      ),
    ),
  );
}
