import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/presentation/manager/checkout/checkout_cubit.dart';
import 'package:new_coffee/features/coupon/data/repositories/coupon_repository.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_cubit.dart';
import 'package:new_coffee/features/coupon/presentation/manager/coupons/coupons_state.dart';
import 'package:new_coffee/features/coupon/presentation/views/widgets/coupon_card.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
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
          // A re-read keeps the offers the customer is reading: only a page
          // that has never been answered is worth a skeleton.
          if (state.isLoading && state.coupons.isEmpty) {
            return const CouponsLoadingView();
          }
          if (state.coupons.isEmpty) {
            // Nothing on screen and a failure behind it: say which of the two
            // the customer is looking at, and give the tap that can fix it.
            if (state.errorMessage != null) {
              return EmptyState(
                icon: AppIcons.discountTag,
                title: S.couldNotLoadCoupons,
                actionLabel: S.retry,
                onAction: () => context.read<CouponsCubit>().load(),
              );
            }
            return EmptyState(
              icon: AppIcons.discountTag,
              title: S.noCoupons,
              subtitle: S.noCouponsHint,
            );
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
              if (state.errorMessage != null) ...[
                _OutdatedNotice(
                  onRetry: () => context.read<CouponsCubit>().load(),
                ),
                SizedBox(height: AppSpacing.md),
              ],
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

/// A re-read that failed while the offers from the last answer stay on screen.
///
/// The list is kept because it is what the customer came to read; the notice
/// says it may not be current and offers the retry a replaced screen would have
/// hidden. The reason the server gave is never printed.
class _OutdatedNotice extends StatelessWidget {
  const _OutdatedNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.primarySoft,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(S.couponsOutdated, style: AppFonts.regular14(context)),
          ),
          Semantics(
            button: true,
            label: S.retry,
            child: Material(
              color: AppColor.transparent,
              child: TextButton(onPressed: onRetry, child: Text(S.retry)),
            ),
          ),
        ],
      ),
    );
  }
}
