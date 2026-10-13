import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SpacingTokens.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64.w,
              color: AppColor.greyColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: SpacingTokens.md.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.semiBold16(context),
            ),
            if (subtitle != null) ...[
              SizedBox(height: SpacingTokens.xs.h),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppFonts.regular14(
                  context,
                ).copyWith(color: AppColor.greyColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
