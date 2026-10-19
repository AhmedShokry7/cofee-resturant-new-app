import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({
    super.key,
    required this.percent,
    this.size = 40,
    this.textAlignment = Alignment.bottomLeft,
    this.textPadding = const EdgeInsets.only(
      left: 3,
      bottom: 4,
    ),
  });

  final int percent;
  final double size;
  final Alignment textAlignment;
  final EdgeInsetsGeometry textPadding;

  static const double cardSize = 50;
  static const double cardTop = -1;
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
            image: AssetImage('assets/icons/discount.png'),
            fit: BoxFit.contain,
          ),
        ),
        alignment: textAlignment,
        child: Padding(
          padding: EdgeInsets.only(
            left: 12.w,
            bottom: 4.h,
          ),
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