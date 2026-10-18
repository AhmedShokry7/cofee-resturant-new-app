import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;

  /// Secondary line under [label], e.g. the currently selected value.
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: SpacingTokens.lg.w,
              vertical: SpacingTokens.md.h,
            ),
            child: Row(
              children: [
                Icon(icon, size: 24.w, color: AppColor.primaryColor),
                SizedBox(width: SpacingTokens.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: AppFonts.regular16(context)),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: AppFonts.regular12(
                            context,
                          ).copyWith(color: AppColor.greyColor),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  HugeIcons.strokeRoundedArrowRight01,
                  size: 20.w,
                  color: AppColor.greyColor,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

