import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The grab bar every bottom sheet opens with.
///
/// Four sheets drew this by hand with the same size and colour, so a change to
/// the handle meant finding all four.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      height: AppSpacing.xs,
      width: AppDimensions.sheetHandleWidth,
      decoration: BoxDecoration(
        color: AppColor.borderColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
  );
}
