import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({
    super.key,
    required this.percent,
    this.size = 40,
    this.textAlignment = AlignmentDirectional.bottomStart,
    this.textPadding = const EdgeInsetsDirectional.only(start: 3, bottom: 4),
  });

  final int percent;
  final double size;
  final AlignmentGeometry textAlignment;
  final EdgeInsetsGeometry textPadding;

  static const double cardSize = 50;
  static const double cardTop = 0;
  static const double cardRight = 0;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size.w;

    return SizedBox(
      width: badgeSize,
      height: badgeSize,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppImages.discount),
            matchTextDirection: true,
            fit: BoxFit.contain,
          ),
        ),
        alignment: textAlignment,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: 12.w, bottom: 4.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$percent',
                maxLines: 1,
                style: AppFonts.bold12(context).copyWith(
                  color: AppColor.whiteColor,
                  fontSize: (size * 0.30).sp,
                  fontWeight: FontWeight.w800,
                  height: 0.85,
                ),
              ),
              Text(
                '%',
                maxLines: 1,
                style: AppFonts.bold12(context).copyWith(
                  color: AppColor.whiteColor,
                  fontSize: (size * 0.30).sp,
                  fontWeight: FontWeight.w900,
                  height: 0.75,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
