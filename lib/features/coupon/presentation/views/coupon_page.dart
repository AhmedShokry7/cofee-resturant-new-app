import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/coupon/data/model/coupon_model.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/coupon/presentation/views/widgets/coupon_card.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

class CouponPage extends StatefulWidget {
  const CouponPage({super.key});

  static const routeName = "couponRoute";

  @override
  State<CouponPage> createState() => _CouponPageState();
}

class _CouponPageState extends State<CouponPage> {
  // Held in state so the list is fetched once and can be refreshed after a
  // coupon is applied from here, instead of re-issuing the query on every
  // rebuild.
  late Future<List<CouponModel>> _couponsFuture;

  @override
  void initState() {
    super.initState();
    _couponsFuture = context.read<CouponRepository>().activeCoupons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.coupon)),
      body: FutureBuilder<List<CouponModel>>(
        future: _couponsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CouponsLoadingView();
          }
          if (snapshot.hasError) {
            return Center(child: Text(S.couponsLoadError('${snapshot.error}')));
          }
          final coupons = snapshot.data ?? const [];
          if (coupons.isEmpty) {
            return Center(child: Text(S.noCoupons));
          }
          // Highlights the code already attached to the cart so the customer
          // can see which offer they are actually getting.
          final appliedCode = context
              .watch<CheckoutCubit>()
              .state
              .appliedCoupon
              ?.coupon
              .code;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              SpacingTokens.lg.w,
              SpacingTokens.md.h,
              SpacingTokens.lg.w,
              SpacingTokens.lg.w,
            ),
            children: [
              Text(S.bestOffers, style: AppFonts.semiBold18(context)),
              SizedBox(height: SpacingTokens.lg.h),
              ...coupons.map(
                (coupon) => CouponCard(
                  coupon: coupon,
                  isApplied: coupon.code == appliedCode,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
