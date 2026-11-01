import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_cubit.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_state.dart';
import 'package:new_coffee/features/coupon/presentation/views/widgets/coupon_card.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class CouponPage extends StatelessWidget {
  const CouponPage({super.key});

  static const routeName = "couponRoute";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CouponsCubit(repository: context.read<CouponRepository>()),
      child: const _CouponsView(),
    );
  }
}

class _CouponsView extends StatelessWidget {
  const _CouponsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.coupon)),
      body: BlocBuilder<CouponsCubit, CouponsState>(
        builder: (context, state) {
          if (state.isLoading) return const CouponsLoadingView();
          if (state.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.couldNotLoadCoupons, textAlign: TextAlign.center),
                  SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.read<CouponsCubit>().load(),
                    child: Text(S.retry),
                  ),
                ],
              ),
            );
          }
          if (state.coupons.isEmpty) {
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
            padding: AppLayout.pageBody,
            children: [
              Text(S.bestOffers, style: AppFonts.semiBold18(context)),
              SizedBox(height: AppSpacing.lg),
              ...state.coupons.map(
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
