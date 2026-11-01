import 'package:flutter/material.dart';

import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Skeleton that mirrors [ProductCard] in its grid/carousel variant.
///
/// Layout contract (product_card.dart): finite cell width (or
/// [AppBreakpoints.productCardMinWidth] when the horizontal parent is
/// unbounded), the card aspect ratio, `md` padding, [AppRadius.r16] corners, image
/// Expanded with [AppRadius.r12] plus an [AppSizes.px28] favorite badge, then
/// title / description lines and a price + [AppSizes.px36] add-button row.
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
            (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : AppDimensions.productCardWidth);
        return SizedBox(
          width: resolved,
          child: AspectRatio(
            // Mirrors ProductCard.cardAspectRatio (kept literal to avoid a
            // shared -> feature import).
            aspectRatio: ProductCard.cardAspectRatio,
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: skeletonCardDecoration(
                context,
                radius: AppRadius.r16,
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
                              borderRadius: BorderRadius.circular(
                                AppDimensions.cardRadius,
                              ),
                            ),
                          ),
                          Positioned(
                            top: AppSpacing.xxs,
                            left: AppSpacing.xs,
                            child: ShimmerCircle(size: AppSizes.px28),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    const ShimmerLine(widthFactor: 0.9, height: AppSizes.px15),
                    SizedBox(height: AppSpacing.xs),
                    const ShimmerLine(widthFactor: 0.65, height: AppSizes.px11),
                    SizedBox(height: AppSizes.px6),
                    Row(
                      children: [
                        const Expanded(
                          child: ShimmerLine(
                            widthFactor: 0.8,
                            height: AppSizes.px13,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        ShimmerCircle(size: AppSizes.px36),
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

/// Skeleton grid mirroring [ProductsGridView]: same outer padding, the same
/// self-counting row, the same spacings and the same child aspect ratio, so
/// real cards replace skeleton cards without any layout shift.
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
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: AppBreakpoints.productCardMaxWidth,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: ProductCard.cardAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ProductCardSkeleton(),
    );
  }
}

/// Skeleton carousel mirroring [HomeProductsCarousel]: section title row plus
/// a horizontal list of fixed [AppDimensions.productCardWidth] product cards whose strip height is
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
              const ShimmerLine(
                width: AppDimensions.skeletonLineLong,
                height: AppDimensions.skeletonLineHeight,
                radius: AppRadius.r8,
              ),
              ShimmerBox(
                width: AppSizes.px64,
                height: AppSpacing.md,
                borderRadius: BorderRadius.circular(AppRadius.r6),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: AppSpacing.xs),
          const Shimmer(child: ShimmerLine(widthFactor: 0.5, height: 11)),
        ],
        SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppDimensions.productCardWidth / ProductCard.cardAspectRatio,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) =>
                SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) =>
                ProductCardSkeleton(width: AppDimensions.productCardWidth),
          ),
        ),
      ],
    );
  }
}

/// Skeleton bundle card mirroring the home bundles carousel card:
/// [AppDimensions.bundleCardWidth] wide, [AppDimensions.bundleSectionHeight] list height, radius [AppRadius.r16], image radius [AppRadius.r12], title /
/// subtitle lines and a price row.
class BundleCardSkeleton extends StatelessWidget {
  const BundleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.bundleCardWidth,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: skeletonCardDecoration(context, radius: AppRadius.r16),
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShimmerBox(
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            const ShimmerLine(widthFactor: 0.9, height: 13),
            SizedBox(height: AppSpacing.xs),
            const ShimmerLine(widthFactor: 0.6, height: 11),
            SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const ShimmerLine(
                  width: AppDimensions.skeletonThumbLine,
                  height: AppDimensions.skeletonCaptionHeight,
                  radius: AppRadius.r6,
                ),
                SizedBox(width: AppSpacing.xs),
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

/// Skeleton mirroring [HomeBundlesSection]: title plus a [AppDimensions.bundleSectionHeight] horizontal
/// list of [AppDimensions.bundleCardWidth] bundle cards.
class BundlesCarouselSkeleton extends StatelessWidget {
  const BundlesCarouselSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Shimmer(
          child: ShimmerLine(
            width: AppDimensions.skeletonLineMedium,
            height: AppDimensions.skeletonLineHeight,
            radius: AppRadius.r8,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AppDimensions.bundleSectionHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (context, index) =>
                SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => const BundleCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

/// Skeleton row mirroring [BundleListTile]: [AppSizes.px78] thumbnail radius [AppRadius.r12],
/// title / subtitle / price lines and a trailing arrow slot.
class BundleListTileSkeleton extends StatelessWidget {
  const BundleListTileSkeleton({super.key});

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
              width: AppSizes.px78,
              height: AppSizes.px78,
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(widthFactor: 0.85, height: 15),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerLine(widthFactor: 0.6, height: 11),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerLine(
                    width: AppDimensions.skeletonLineShort,
                    height: AppDimensions.skeletonCaptionHeight,
                    radius: AppRadius.r6,
                  ),
                ],
              ),
            ),
            ShimmerCircle(size: AppSizes.px20),
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
      padding: skeletonListPadding(context),
      itemCount: itemCount,
      itemBuilder: (context, index) => const BundleListTileSkeleton(),
    );
  }
}

/// Skeleton tabs mirroring [CategoryTabs]: a [AppDimensions.tabBarHeight] bar with a bottom border
/// and horizontally laid out tab pills.
class CategoryTabsSkeleton extends StatelessWidget {
  const CategoryTabsSkeleton({super.key, this.tabCount = 4});

  final int tabCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.tabBarHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.borderColor)),
      ),
      child: Shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: tabCount,
          separatorBuilder: (context, index) => SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) => Center(
            child: ShimmerBox(
              width: index == 0
                  ? AppDimensions.skeletonTabWidth
                  : AppDimensions.skeletonTabShortWidth,
              height: AppSpacing.lg,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single skeleton cell mirroring [CategoryGridItem]: [AppSizes.px56] tile radius [AppRadius.r16]
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
            width: AppSizes.px56,
            height: AppSizes.px56,
            borderRadius: BorderRadius.circular(AppRadius.r16),
          ),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(
            width: AppSizes.px44,
            height: AppSizes.px11,
            borderRadius: BorderRadius.circular(AppRadius.r6),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerLine(
                width: AppDimensions.skeletonLineMedium,
                height: AppDimensions.skeletonTitleHeight,
                radius: AppRadius.r8,
              ),
              ShimmerBox(
                width: AppSizes.px52,
                height: AppSpacing.md,
                borderRadius: BorderRadius.circular(AppRadius.r6),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = HomeCategoriesSection.tileExtent(constraints);
            return SizedBox(
              height: HomeCategoriesSection.gridHeight(constraints),
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: HomeCategoriesSection.gridRows,
                  mainAxisSpacing: HomeCategoriesSection.gap,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: itemWidth,
                ),
                itemCount:
                    HomeCategoriesSection.gridColumns *
                    HomeCategoriesSection.gridRows,
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

/// Skeleton mirroring the home banner carousel: full-bleed [AppDimensions.homeBannerHeight] image plus
/// the dots indicator row below it.
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({
    super.key,
    this.borderRadius = 0,
    this.height = AppDimensions.homeBannerHeight,
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
            height: height,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          if (showDots) ...[
            SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerCircle(size: AppSizes.px10),
                SizedBox(width: AppSpacing.xs),
                ShimmerCircle(size: AppSpacing.sm),
                SizedBox(width: AppSpacing.xs),
                ShimmerCircle(size: AppSpacing.sm),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
