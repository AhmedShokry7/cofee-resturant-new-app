import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
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
            Text(S.logOut, style: AppFonts.semiBold18(context)),
            SizedBox(height: SpacingTokens.md.h),
            Text(
              S.logoutConfirm,
              textAlign: TextAlign.center,
              style: AppFonts.regular16(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            const Divider(),
            SizedBox(height: SpacingTokens.lg.h),
            Row(
              children: [
                Expanded(
                  child: CustomBtn(
                    text: S.cancel,
                    variant: BtnVariant.secondary,
                    textColor: AppColor.primaryColor,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: CustomBtn(
                    text: S.confirmLogout,
                    // Close first, then sign out. The sheet has to go before
                    // the network call so that a failure leaves the customer on
                    // the settings page with an explanation and the option to
                    // try again, rather than stuck behind an open sheet.
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
