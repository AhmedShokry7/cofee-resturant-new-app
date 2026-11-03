import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Skeleton mirroring [ProductDetailsBody]: full-bleed [AppDimensions.productHeroHeight] image flush
/// under the AppBar, then the padded info column — category line, title +
/// price row, quantity row, description block and two option-group blocks
/// with chip rows. Same paddings, gaps and radii as the loaded page, so real
/// content replaces it without any layout shift.
class ProductDetailsSkeleton extends StatelessWidget {
  const ProductDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? AppColor.darkSurface
        : AppColor.whiteColor;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Full-bleed hero, unchanged.
        Shimmer(
          child: ShimmerBox(
            width: double.infinity,
            height: AppDimensions.productHeroHeight,
          ),
        ),
        // Rounded sheet that overlaps the hero, mirroring the loaded page so
        // real content drops in without a layout shift.
        Transform.translate(
          offset: const Offset(0, -28),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.r24),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Shimmer(child: ShimmerLine(width: 100, height: 13)),
                SizedBox(height: AppSpacing.xs),
                Shimmer(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: ShimmerLine(widthFactor: 0.9, height: 19),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      ShimmerBox(
                        width: AppSizes.px72,
                        height: AppSizes.px18,
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Shimmer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const ShimmerLine(width: 90, height: 15),
                      ShimmerBox(
                        width: AppDimensions.skeletonChipWidth,
                        height: AppSizes.px36,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                const Shimmer(child: ShimmerLine(width: 140, height: 15)),
                SizedBox(height: AppSpacing.sm),
                const Shimmer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLine(widthFactor: 1, height: 13),
                      SizedBox(height: AppDimensions.skeletonLineGap),
                      ShimmerLine(widthFactor: 1, height: 13),
                      SizedBox(height: AppDimensions.skeletonLineGap),
                      ShimmerLine(widthFactor: 0.6, height: 13),
                    ],
                  ),
                ),
                for (var group = 0; group < 2; group++) ...[
                  SizedBox(height: AppSpacing.lg),
                  Shimmer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerLine(
                          width: AppDimensions.skeletonChipShortWidth,
                          height: 15,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: ShimmerBox(
                                  height: AppDimensions.buttonHeight,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.cardRadius,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.xl),
                const ProductsCarouselSkeleton(itemCount: 3),
                SizedBox(height: AppSpacing.lg),
                const Divider(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton mirroring the bundle details body: full-width [AppDimensions.bundleHeroHeight] hero radius
/// [AppRadius.r16], title / subtitle lines, "what's inside" rows ([AppSpacing.xxxl] thumbs radius
/// [AppRadius.r8]) and three price rows.
class BundleDetailsSkeleton extends StatelessWidget {
  const BundleDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: skeletonListPadding(context),
      children: [
        Shimmer(
          child: ShimmerBox(
            width: double.infinity,
            height: AppDimensions.bundleHeroHeight,
            borderRadius: BorderRadius.circular(AppRadius.r16),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        const Shimmer(child: ShimmerLine(width: 200, height: 19)),
        SizedBox(height: AppSpacing.xs),
        const Shimmer(child: ShimmerLine(widthFactor: 0.7, height: 13)),
        SizedBox(height: AppSpacing.lg),
        const Shimmer(
          child: ShimmerLine(
            width: AppDimensions.skeletonChipWidth,
            height: 15,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < 3; i++)
          Container(
            margin: EdgeInsets.only(bottom: AppSpacing.sm),
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: skeletonCardDecoration(context, radius: AppRadius.r12),
            child: Shimmer(
              child: Row(
                children: [
                  ShimmerBox(
                    width: AppSpacing.xxxl,
                    height: AppSpacing.xxxl,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: ShimmerLine(widthFactor: 0.8, height: 13),
                  ),
                  ShimmerBox(
                    width: AppSizes.px52,
                    height: AppSizes.px13,
                    borderRadius: BorderRadius.circular(AppRadius.r6),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: AppSpacing.md),
        for (var i = 0; i < 3; i++) ...[
          Shimmer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ShimmerLine(
                  width: AppDimensions.skeletonChipShortWidth,
                  height: 13,
                ),
                ShimmerBox(
                  width: AppDimensions.skeletonTagWidth,
                  height: AppSizes.px15,
                  borderRadius: BorderRadius.circular(AppRadius.r6),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(height: AppSpacing.xl),
        const ProductsCarouselSkeleton(itemCount: 3),
      ],
    );
  }
}

/// Single skeleton row mirroring [OrderCard]: [AppSizes.px72] thumbnail radius [AppRadius.r8],
/// order-number / name / price lines and the action pill slot.
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: skeletonCardDecoration(context, radius: AppRadius.r12),
      child: Shimmer(
        child: Row(
          children: [
            ShimmerBox(
              width: AppSizes.px72,
              height: AppSizes.px72,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(width: 90, height: 11),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerLine(widthFactor: 0.95, height: 15),
                  SizedBox(height: AppDimensions.skeletonLineGap),
                  ShimmerLine(
                    width: AppDimensions.skeletonLineBrief,
                    height: AppDimensions.skeletonCaptionHeight,
                    radius: AppRadius.r6,
                  ),
                ],
              ),
            ),
            ShimmerBox(
              width: AppDimensions.skeletonPillWidth,
              height: AppSizes.px30,
              borderRadius: BorderRadius.circular(AppRadius.pill),
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
      padding: skeletonListPadding(context),
      itemCount: itemCount,
      itemBuilder: (context, index) => const OrderCardSkeleton(),
    );
  }
}

/// Skeleton for the cart lines.
///
/// The cart belongs to an account and a branch, so it only exists after a read:
/// a device slot and, for a signed-in customer, a server round trip. Rows shown
/// while that is on their way, so an empty cart is never flashed at a customer
/// who has lines.
class CartLinesSkeleton extends StatelessWidget {
  const CartLinesSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: skeletonListPadding(context),
      itemCount: itemCount,
      itemBuilder: (context, index) => const _CartLineTileSkeleton(),
    );
  }
}

/// One row, mirroring the cart variant of [ProductCard]: [AppSizes.px76] image,
/// the name and line-total columns, and the unit price over the stepper.
class _CartLineTileSkeleton extends StatelessWidget {
  const _CartLineTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: skeletonCardDecoration(context, radius: AppRadius.r16),
      child: Shimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShimmerBox(
              width: AppSizes.px76,
              height: AppSizes.px76,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(widthFactor: 0.7, height: AppSizes.px15),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerLine(widthFactor: 0.4, height: AppSizes.px13),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShimmerLine(
                  width: AppDimensions.skeletonLineShort,
                  height: AppSizes.px11,
                ),
                SizedBox(height: AppSpacing.xs),
                ShimmerLine(width: AppSizes.px72, height: AppSizes.px28),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Single skeleton row mirroring [NotificationTile]: [AppSizes.px44] icon box radius
/// [AppRadius.r12], title + time row and body lines.
class NotificationTileSkeleton extends StatelessWidget {
  const NotificationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: skeletonCardDecoration(context, radius: AppRadius.r16),
      child: Shimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(
              width: AppSizes.px44,
              height: AppSizes.px44,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: ShimmerLine(widthFactor: 0.9, height: 15),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      ShimmerBox(
                        width: AppSizes.px44,
                        height: AppSizes.px11,
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  const ShimmerLine(widthFactor: 1, height: 13),
                  SizedBox(height: AppSpacing.xs),
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
      padding: skeletonListPadding(context),
      itemCount: itemCount,
      itemBuilder: (context, index) => const NotificationTileSkeleton(),
    );
  }
}

/// Single skeleton card mirroring [CouponCard]: [AppSizes.px44] circle icon, title /
/// description / discount lines and the copy-code footer strip.
class CouponCardSkeleton extends StatelessWidget {
  const CouponCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      decoration: skeletonCardDecoration(context, radius: AppRadius.r16),
      child: Shimmer(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerCircle(size: AppSizes.px44),
                  SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLine(widthFactor: 0.8, height: 15),
                        SizedBox(height: AppSpacing.xs),
                        ShimmerLine(widthFactor: 1, height: 11),
                        SizedBox(height: AppSpacing.sm),
                        ShimmerLine(
                          width: AppDimensions.skeletonLineTile,
                          height: AppDimensions.skeletonCaptionHeight,
                          radius: AppRadius.r6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: AppColor.lightGreyColor,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: ShimmerBox(
                  width: AppDimensions.skeletonChipShortWidth,
                  height: AppSizes.px15,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
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
      padding: skeletonListPadding(context),
      children: [
        const Shimmer(child: ShimmerLine(width: 130, height: 17)),
        SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < itemCount; i++) const CouponCardSkeleton(),
      ],
    );
  }
}

/// Single skeleton row mirroring [RewardCard]: [AppSizes.px56] thumbnail radius [AppRadius.r12],
/// name / cost lines and the redeem pill slot.
class RewardCardSkeleton extends StatelessWidget {
  const RewardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: skeletonCardDecoration(context, radius: AppRadius.r16),
      child: Shimmer(
        child: Row(
          children: [
            ShimmerBox(
              width: AppSizes.px56,
              height: AppSizes.px56,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(widthFactor: 0.85, height: 15),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerLine(
                    width: AppDimensions.skeletonLineShort,
                    height: AppDimensions.skeletonCaptionHeight,
                    radius: AppRadius.r6,
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            ShimmerBox(
              width: AppSizes.px78,
              height: AppSpacing.xxl,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton mirroring [LoyaltyPage]: gradient-shaped balance card (padding
/// xl, radius [AppRadius.r20]), section headings and reward rows.
class LoyaltyLoadingView extends StatelessWidget {
  const LoyaltyLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: skeletonListPadding(context),
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.xl),
          decoration: skeletonCardDecoration(context, radius: AppRadius.r20),
          child: Shimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLine(
                  width: AppDimensions.skeletonChipWidth,
                  height: 13,
                ),
                SizedBox(height: AppSpacing.xs),
                const ShimmerLine(
                  width: AppDimensions.skeletonBlock,
                  height: AppDimensions.skeletonBlockHeight,
                  radius: AppRadius.r8,
                ),
                SizedBox(height: AppSpacing.xs),
                const ShimmerLine(widthFactor: 0.8, height: 11),
                SizedBox(height: AppSpacing.xs),
                const ShimmerLine(widthFactor: 0.6, height: 11),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        const Shimmer(child: ShimmerLine(width: 180, height: 17)),
        SizedBox(height: AppSpacing.md),
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
            if (i > 0) SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerCircle(size: AppSizes.px20),
                SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLine(widthFactor: 0.7, height: 14),
                      SizedBox(height: AppSpacing.xs),
                      ShimmerLine(widthFactor: 0.45, height: 11),
                    ],
                  ),
                ),
                ShimmerBox(
                  width: AppSizes.px52,
                  height: AppSizes.px11,
                  borderRadius: BorderRadius.circular(AppRadius.r6),
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
/// [AppRadius.r12], bottom margin md) with a title line and chevron slot.
class FaqLoadingView extends StatelessWidget {
  const FaqLoadingView({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: skeletonListPadding(context),
      children: [
        const Shimmer(child: ShimmerLine(width: 150, height: 15)),
        SizedBox(height: AppSpacing.md),
        for (var i = 0; i < itemCount; i++)
          Container(
            margin: EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: skeletonCardDecoration(context, radius: AppRadius.r12),
            child: Shimmer(
              child: Row(
                children: [
                  const Expanded(
                    child: ShimmerLine(widthFactor: 0.9, height: 14),
                  ),
                  SizedBox(width: AppSpacing.md),
                  ShimmerCircle(size: AppSizes.px22),
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
      padding: skeletonListPadding(context),
      children: [
        Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 9; i++) ...[
                if (i > 0) SizedBox(height: AppSpacing.sm),
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
