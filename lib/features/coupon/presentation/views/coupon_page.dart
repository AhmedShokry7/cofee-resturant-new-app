import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/coupon/data/coupons_list.dart';
import 'package:new_coffee/features/coupon/presentation/views/widgets/coupon_card.dart';

class CouponPage extends StatelessWidget {
  const CouponPage({super.key});

  static const routeName = "couponRoute";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Coupon")),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.lg.w,
          SpacingTokens.md.h,
          SpacingTokens.lg.w,
          SpacingTokens.lg.w,
        ),
        children: [
          Text("Best offers for you", style: AppFonts.semiBold18(context)),
          SizedBox(height: SpacingTokens.lg.h),
          ...getCouponsList().map((coupon) => CouponCard(coupon: coupon)),
        ],
      ),
    );
  }
}

