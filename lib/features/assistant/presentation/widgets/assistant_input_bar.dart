import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

Widget assistantInputBar({
  required BuildContext context,
  required TextEditingController controller,
  required VoidCallback onSubmitted,
  required VoidCallback onSend,
}) {
  return Row(
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          onSubmitted: (_) => onSubmitted(),
          style: AppFonts.regular14(context),
          decoration: InputDecoration(
            hintText: 'Ask me anything…',
            contentPadding: EdgeInsets.symmetric(
              horizontal: SpacingTokens.md.w,
              vertical: SpacingTokens.sm.h,
            ),
            filled: true,
            fillColor: AppColor.lightGreyColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      SizedBox(width: SpacingTokens.sm.w),
      GestureDetector(
        onTap: onSend,
        child: Container(
          height: 48.w,
          width: 48.w,
          decoration: const BoxDecoration(
            color: AppColor.primaryColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            HugeIcons.strokeRoundedSent,
            size: 22.w,
            color: AppColor.whiteColor,
          ),
        ),
      ),
    ],
  );
}