import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

/// Skeleton mirroring [ProductDetailsBody]: full-bleed 300.h image flush
/// under the AppBar, then the padded info column — category line, title +
/// price row, quantity row, description block and two option-group blocks
/// with chip rows. Same paddings, gaps and radii as the loaded page, so real
/// content replaces it without any layout shift.
class ProductDetailsSkeleton extends StatelessWidget {
  const ProductDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: SpacingTokens.lg.h),
      children: [
        Shimmer(
          child: ShimmerBox(width: double.infinity, height: 300.h),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.lg.w,
            SpacingTokens.md.h,
            SpacingTokens.lg.w,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Shimmer(child: ShimmerLine(width: 100, height: 13)),
              SizedBox(height: 4.h),
              Shimmer(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: ShimmerLine(widthFactor: 0.9, height: 19),
                    ),
                    SizedBox(width: SpacingTokens.sm.w),
                    ShimmerBox(
                      width: 72.w,
                      height: 18.h,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ],
                ),
              ),
              SizedBox(height: SpacingTokens.lg.h),
              Shimmer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ShimmerLine(width: 90, height: 15),
                    ShimmerBox(
                      width: 120.w,
                      height: 36.h,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ],
                ),
              ),
              SizedBox(height: SpacingTokens.lg.h),
              const Shimmer(child: ShimmerLine(width: 140, height: 15)),
              SizedBox(height: SpacingTokens.sm.h),
              const Shimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerLine(widthFactor: 1, height: 13),
                    SizedBox(height: 6),
                    ShimmerLine(widthFactor: 1, height: 13),
                    SizedBox(height: 6),
                    ShimmerLine(widthFactor: 0.6, height: 13),
                  ],
                ),
              ),
              for (var group = 0; group < 2; group++) ...[
                SizedBox(height: SpacingTokens.lg.h),
                Shimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ShimmerLine(width: 110, height: 15),
                      SizedBox(height: SpacingTokens.xs.h),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) SizedBox(width: SpacingTokens.sm.w),
                            Expanded(
                              child: ShimmerBox(
                                height: 52.h,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: SpacingTokens.xl.h),
              const ProductsCarouselSkeleton(itemCount: 3),
              SizedBox(height: SpacingTokens.lg.h),
              const Divider(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton mirroring the bundle details body: full-width 200.h hero radius
/// 16.r, title / subtitle lines, "what's inside" rows (48.w thumbs radius
/// 8.r) and three price rows.
class BundleDetailsSkeleton extends StatelessWidget {
  const BundleDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        Shimmer(
          child: ShimmerBox(
            width: double.infinity,
            height: 200.h,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        SizedBox(height: SpacingTokens.lg.h),
        const Shimmer(child: ShimmerLine(width: 200, height: 19)),
        SizedBox(height: 4.h),
        const Shimmer(child: ShimmerLine(widthFactor: 0.7, height: 13)),
        SizedBox(height: SpacingTokens.lg.h),
        const Shimmer(child: ShimmerLine(width: 120, height: 15)),
        SizedBox(height: SpacingTokens.sm.h),
        for (var i = 0; i < 3; i++)
          Container(
            margin: EdgeInsets.only(bottom: SpacingTokens.sm.h),
            padding: EdgeInsets.all(SpacingTokens.sm.w),
            decoration: BoxDecoration(
              color: AppColor.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColor.borderColor),
            ),
            child: Shimmer(
              child: Row(
                children: [
                  ShimmerBox(
                    width: 48.w,
                    height: 48.w,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  SizedBox(width: SpacingTokens.sm.w),
                  const Expanded(
                    child: ShimmerLine(widthFactor: 0.8, height: 13),
                  ),
                  ShimmerBox(
                    width: 52.w,
                    height: 13.h,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: SpacingTokens.md.h),
        for (var i = 0; i < 3; i++) ...[
          Shimmer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerLine(width: 110, height: 13),
                ShimmerBox(
                  width: 70.w,
                  height: 15.h,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ],
            ),
          ),
          SizedBox(height: SpacingTokens.xs.h),
        ],
        SizedBox(height: SpacingTokens.xl.h),
        const ProductsCarouselSkeleton(itemCount: 3),
      ],
    );
  }
}

/// Single skeleton row mirroring [OrderCard]: 72.w thumbnail radius 8.r,
/// order-number / name / price lines and the action pill slot.
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Shimmer(
        child: Row(
          children: [
            ShimmerBox(
              width: 72.w,
              height: 72.w,
              borderRadius: BorderRadius.circular(8.r),
            ),
            SizedBox(width: SpacingTokens.md.w),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(width: 90, height: 11),
                  SizedBox(height: 4),
                  ShimmerLine(widthFactor: 0.95, height: 15),
                  SizedBox(height: 6),
                  ShimmerLine(width: 80, height: 13, radius: 6),
                ],
              ),
            ),
            ShimmerBox(
              width: 84.w,
              height: 30.h,
              borderRadius: BorderRadius.circular(100.r),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list mirroring the orders list padding.
class OrdersSkeleton extends StatelessWidget {
  const OrdersSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const OrderCardSkeleton(),
    );
  }
}

/// Single skeleton row mirroring [NotificationTile]: 44.w icon box radius
/// 12.r, title + time row and body lines.
class NotificationTileSkeleton extends StatelessWidget {
  const NotificationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Shimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(
              width: 44.w,
              height: 44.w,
              borderRadius: BorderRadius.circular(12.r),
            ),
            SizedBox(width: SpacingTokens.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: ShimmerLine(widthFactor: 0.9, height: 15),
                      ),
                      SizedBox(width: SpacingTokens.sm.w),
                      ShimmerBox(
                        width: 44.w,
                        height: 11.h,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  const ShimmerLine(widthFactor: 1, height: 13),
                  SizedBox(height: 4.h),
                  const ShimmerLine(widthFactor: 0.7, height: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton list mirroring the notifications list padding.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const NotificationTileSkeleton(),
    );
  }
}

/// Single skeleton card mirroring [CouponCard]: 44.w circle icon, title /
/// description / discount lines and the copy-code footer strip.
class CouponCardSkeleton extends StatelessWidget {
  const CouponCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.lg.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Shimmer(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(SpacingTokens.md.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCircle(size: 44.w),
                  SizedBox(width: SpacingTokens.md.w),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLine(widthFactor: 0.8, height: 15),
                        SizedBox(height: 4),
                        ShimmerLine(widthFactor: 1, height: 11),
                        SizedBox(height: 8),
                        ShimmerLine(width: 100, height: 13, radius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: AppColor.lightGreyColor,
              padding: EdgeInsets.symmetric(vertical: SpacingTokens.md.h),
              child: Center(
                child: ShimmerBox(
                  width: 110.w,
                  height: 15.h,
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton mirroring [CouponPage]: section heading plus coupon cards with
/// the same outer padding.
class CouponsLoadingView extends StatelessWidget {
  const CouponsLoadingView({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        const Shimmer(child: ShimmerLine(width: 130, height: 17)),
        SizedBox(height: SpacingTokens.lg.h),
        for (var i = 0; i < itemCount; i++) const CouponCardSkeleton(),
      ],
    );
  }
}

/// Single skeleton row mirroring [RewardCard]: 56.w thumbnail radius 12.r,
/// name / cost lines and the redeem pill slot.
class RewardCardSkeleton extends StatelessWidget {
  const RewardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Shimmer(
        child: Row(
          children: [
            ShimmerBox(
              width: 56.w,
              height: 56.w,
              borderRadius: BorderRadius.circular(12.r),
            ),
            SizedBox(width: SpacingTokens.md.w),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(widthFactor: 0.85, height: 15),
                  SizedBox(height: 4),
                  ShimmerLine(width: 90, height: 13, radius: 6),
                ],
              ),
            ),
            SizedBox(width: SpacingTokens.sm.w),
            ShimmerBox(
              width: 78.w,
              height: 32.h,
              borderRadius: BorderRadius.circular(100.r),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton mirroring [LoyaltyPage]: gradient-shaped balance card (padding
/// xl.w, radius 20.r), section headings and reward rows.
class LoyaltyLoadingView extends StatelessWidget {
  const LoyaltyLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(SpacingTokens.xl.w),
          decoration: BoxDecoration(
            color: AppColor.whiteColor,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColor.borderColor),
          ),
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLine(width: 120, height: 13),
                SizedBox(height: SpacingTokens.xs.h),
                const ShimmerLine(width: 160, height: 30, radius: 8),
                SizedBox(height: SpacingTokens.xs.h),
                const ShimmerLine(widthFactor: 0.8, height: 11),
                SizedBox(height: SpacingTokens.xs.h),
                const ShimmerLine(widthFactor: 0.6, height: 11),
              ],
            ),
          ),
        ),
        SizedBox(height: SpacingTokens.xl.h),
        const Shimmer(child: ShimmerLine(width: 180, height: 17)),
        SizedBox(height: SpacingTokens.md.h),
        for (var i = 0; i < 3; i++) const RewardCardSkeleton(),
      ],
    );
  }
}

/// Skeleton for the live-status timeline section of the track-order page.
/// The order header card above it already shows real data; only the timeline
/// rows shimmer.
class TrackTimelineSkeleton extends StatelessWidget {
  const TrackTimelineSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) SizedBox(height: SpacingTokens.md.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerCircle(size: 20.w),
                SizedBox(width: SpacingTokens.md.w),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLine(widthFactor: 0.7, height: 14),
                      SizedBox(height: 4),
                      ShimmerLine(widthFactor: 0.45, height: 11),
                    ],
                  ),
                ),
                ShimmerBox(
                  width: 52.w,
                  height: 11.h,
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton mirroring [HelpPage]: section heading plus FAQ tiles (radius
/// 12.r, bottom margin md.h) with a title line and chevron slot.
class FaqLoadingView extends StatelessWidget {
  const FaqLoadingView({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        const Shimmer(child: ShimmerLine(width: 150, height: 15)),
        SizedBox(height: SpacingTokens.md.h),
        for (var i = 0; i < itemCount; i++)
          Container(
            margin: EdgeInsets.only(bottom: SpacingTokens.md.h),
            padding: EdgeInsets.symmetric(
              horizontal: SpacingTokens.lg.w,
              vertical: SpacingTokens.md.h,
            ),
            decoration: BoxDecoration(
              color: AppColor.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColor.borderColor),
            ),
            child: Shimmer(
              child: Row(
                children: [
                  const Expanded(
                    child: ShimmerLine(widthFactor: 0.9, height: 14),
                  ),
                  SizedBox(width: SpacingTokens.md.w),
                  ShimmerCircle(size: 22.w),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Skeleton mirroring [PrivacyPolicyPage]: a full-width paragraph of text
/// lines with the same outer padding.
class PolicyLoadingView extends StatelessWidget {
  const PolicyLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.lg.w,
        SpacingTokens.md.h,
        SpacingTokens.lg.w,
        SpacingTokens.lg.w,
      ),
      children: [
        Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 9; i++) ...[
                if (i > 0) SizedBox(height: SpacingTokens.sm.h),
                ShimmerLine(widthFactor: i == 8 ? 0.55 : 1, height: 13),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// First-load skeleton for the categories screen grid. The tab bar above it
/// renders its own skeleton ([CategoryTabsSkeleton]) through [CategoryTabs],
/// so this only covers the grid area with the same paddings the loaded
/// [ProductsGridView] uses.
class CategoriesLoadingView extends StatelessWidget {
  const CategoriesLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductsGridSkeleton();
  }
}
