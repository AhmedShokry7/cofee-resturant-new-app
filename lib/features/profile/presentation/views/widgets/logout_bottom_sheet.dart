import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';

Future<void> showLogoutSheet(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColor.whiteColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
    ),
    builder: (context) => _LogoutSheet(onConfirm: onConfirm),
  );
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4.h,
              width: 100.w,
              decoration: BoxDecoration(
                color: AppColor.borderColor,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            Text("Log Out", style: AppFonts.semiBold18(context)),
            SizedBox(height: SpacingTokens.md.h),
            Text(
              "Are you sure you want to log out ?",
              textAlign: TextAlign.center,
              style: AppFonts.regular16(
                context,
              ).copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            const Divider(),
            SizedBox(height: SpacingTokens.lg.h),
            Row(
              children: [
                Expanded(
                  child: CustomBtn(
                    text: "Cancel",
                    variant: BtnVariant.secondary,
                    textColor: AppColor.primaryColor,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: CustomBtn(text: "Yes, Logout", onPressed: onConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
