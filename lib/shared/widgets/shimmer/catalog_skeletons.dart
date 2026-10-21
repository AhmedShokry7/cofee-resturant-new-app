import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

/// Skeleton that mirrors [ProductCard] in its grid/carousel variant.
///
/// Layout contract (product_card.dart): finite cell width (or 160.w when the
/// horizontal parent is unbounded), AspectRatio 0.60, padding md.w, radius
/// 16.r, image Expanded with radius 12.r plus a 28.w favorite badge, then
/// title / description lines and a price + 36.w add-button row.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width});

  /// Fixed width for unbounded horizontal parents. Null lets the grid cell
  /// dictate the width, exactly like the real card.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolved =
            width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : 168.w);
        return SizedBox(
          width: resolved,
          child: AspectRatio(
            // Mirrors ProductCard.cardAspectRatio (kept literal to avoid a
            // shared -> feature import).
            aspectRatio: 0.60,
            child: Container(
              padding: EdgeInsets.all(SpacingTokens.md.w),
              decoration: BoxDecoration(
                color: AppColor.whiteColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColor.borderColor),
              ),
              child: Shimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ShimmerBox(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          Positioned(
                            top: 2.w,
                            left: 4.w,
                            child: ShimmerCircle(size: 28.w),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: SpacingTokens.sm.h),
                    const ShimmerLine(widthFactor: 0.9, height: 15),
                    SizedBox(height: 4.h),
                    const ShimmerLine(widthFactor: 0.65, height: 11),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        const Expanded(
                          child: ShimmerLine(widthFactor: 0.8, height: 13),
                        ),
                        SizedBox(width: SpacingTokens.xs.w),
                        ShimmerCircle(size: 36.w),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton grid mirroring [ProductsGridView]: same outer padding, 2 columns,
/// same spacings and the same 0.60 child aspect ratio, so real cards replace
/// skeleton cards without any layout shift.
class ProductsGridSkeleton extends StatelessWidget {
  const ProductsGridSkeleton({super.key, this.itemCount = 6, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            SpacingTokens.md.w,
            SpacingTokens.md.h,
            SpacingTokens.md.w,
            SpacingTokens.lg.w,
          ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: SpacingTokens.md.w,
        mainAxisSpacing: SpacingTokens.md.h,
        childAspectRatio: 0.60,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// Skeleton carousel mirroring [HomeProductsCarousel]: section title row plus
/// a horizontal list of fixed 168.w product cards whose strip height is
/// derived from the card aspect ratio, exactly like the real carousel.
class ProductsCarouselSkeleton extends StatelessWidget {
  const ProductsCarouselSkeleton({
    super.key,
    this.itemCount = 4,
    this.showSubtitle = false,
  });

  final int itemCount;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerLine(width: 140, height: 16, radius: 8),
              ShimmerBox(
                width: 64.w,
                height: 12.h,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: 4.h),
          const Shimmer(child: ShimmerLine(widthFactor: 0.5, height: 11)),
        ],
        SizedBox(height: SpacingTokens.md.h),
        SizedBox(
          height: 168.w / 0.60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.md.w),
            itemBuilder: (context, index) => ProductCardSkeleton(width: 168.w),
          ),
        ),
      ],
    );
  }
}

/// Skeleton bundle card mirroring the home bundles carousel card:
/// 180.w wide, 250.h list height, radius 16.r, image radius 12.r, title /
/// subtitle lines and a price row.
class BundleCardSkeleton extends StatelessWidget {
  const BundleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180.w,
      padding: EdgeInsets.all(SpacingTokens.md.w),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShimmerBox(borderRadius: BorderRadius.circular(12.r)),
            ),
            SizedBox(height: SpacingTokens.sm.h),
            const ShimmerLine(widthFactor: 0.9, height: 13),
            SizedBox(height: 4.h),
            const ShimmerLine(widthFactor: 0.6, height: 11),
            SizedBox(height: 4.h),
            Row(
              children: [
                const ShimmerLine(width: 56, height: 13, radius: 6),
                SizedBox(width: SpacingTokens.xs.w),
                const Expanded(
                  child: ShimmerLine(widthFactor: 0.7, height: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton mirroring [HomeBundlesSection]: title plus a 250.h horizontal
/// list of 180.w bundle cards.
class BundlesCarouselSkeleton extends StatelessWidget {
  const BundlesCarouselSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Shimmer(child: ShimmerLine(width: 110, height: 16, radius: 8)),
        SizedBox(height: SpacingTokens.md.h),
        SizedBox(
          height: 250.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.md.w),
            itemBuilder: (context, index) => const BundleCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

/// Skeleton row mirroring [BundleListTile]: 78.w thumbnail radius 12.r,
/// title / subtitle / price lines and a trailing arrow slot.
class BundleListTileSkeleton extends StatelessWidget {
  const BundleListTileSkeleton({super.key});

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
              width: 78.w,
              height: 78.w,
              borderRadius: BorderRadius.circular(12.r),
            ),
            SizedBox(width: SpacingTokens.md.w),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(widthFactor: 0.85, height: 15),
                  SizedBox(height: 4),
                  ShimmerLine(widthFactor: 0.6, height: 11),
                  SizedBox(height: 4),
                  ShimmerLine(width: 90, height: 13, radius: 6),
                ],
              ),
            ),
            ShimmerCircle(size: 20.w),
          ],
        ),
      ),
    );
  }
}

/// Vertical skeleton list mirroring the Bundles tab list padding.
class BundleListSkeleton extends StatelessWidget {
  const BundleListSkeleton({super.key, this.itemCount = 4});

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
      itemBuilder: (context, index) => const BundleListTileSkeleton(),
    );
  }
}

/// Skeleton tabs mirroring [CategoryTabs]: a 50.h bar with a bottom border
/// and horizontally laid out tab pills.
class CategoryTabsSkeleton extends StatelessWidget {
  const CategoryTabsSkeleton({super.key, this.tabCount = 4});

  final int tabCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50.h,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.borderColor)),
      ),
      child: Shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: SpacingTokens.md.w),
          itemCount: tabCount,
          separatorBuilder: (context, index) =>
              SizedBox(width: SpacingTokens.md.w),
          itemBuilder: (context, index) => Center(
            child: ShimmerBox(
              width: (index == 0 ? 96 : 72).w,
              height: 16.h,
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single skeleton cell mirroring [CategoryGridItem]: 56.w tile radius 16.r
/// plus a one-line label.
class CategoryGridItemSkeleton extends StatelessWidget {
  const CategoryGridItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShimmerBox(
            width: 56.w,
            height: 56.w,
            borderRadius: BorderRadius.circular(16.r),
          ),
          SizedBox(height: SpacingTokens.sm.h),
          ShimmerBox(
            width: 44.w,
            height: 11.h,
            borderRadius: BorderRadius.circular(6.r),
          ),
        ],
      ),
    );
  }
}

/// Skeleton mirroring [HomeCategoriesSection]: header row plus the 4x2
/// horizontal category grid with identical gaps and extents.
class HomeCategoriesSkeleton extends StatelessWidget {
  const HomeCategoriesSkeleton({super.key});

  static const int _columns = 4;
  static const int _rows = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerLine(width: 110, height: 18, radius: 8),
              ShimmerBox(
                width: 52.w,
                height: 12.h,
                borderRadius: BorderRadius.circular(6.r),
              ),
            ],
          ),
        ),
        SizedBox(height: SpacingTokens.lg.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = SpacingTokens.sm.w;
            final itemWidth =
                (constraints.maxWidth - (_columns - 1) * gap) / _columns;
            final itemHeight = itemWidth * 1.2;
            return SizedBox(
              height: itemHeight * _rows + SpacingTokens.md.h,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _rows,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: SpacingTokens.md.h,
                  mainAxisExtent: itemWidth,
                ),
                itemCount: _columns * _rows,
                itemBuilder: (context, index) =>
                    const CategoryGridItemSkeleton(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Skeleton mirroring the home banner carousel: full-bleed 164.h image plus
/// the dots indicator row below it.
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({
    super.key,
    this.borderRadius = 0,
    this.height = 164,
    this.showDots = true,
  });

  final double borderRadius;
  final double height;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          ShimmerBox(
            width: double.infinity,
            height: height.h,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          if (showDots) ...[
            SizedBox(height: SpacingTokens.md.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerCircle(size: 10.w),
                SizedBox(width: SpacingTokens.xs.w),
                ShimmerCircle(size: 8.w),
                SizedBox(width: SpacingTokens.xs.w),
                ShimmerCircle(size: 8.w),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
