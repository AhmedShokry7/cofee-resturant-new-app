import 'package:flutter/material.dart';

import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// First-load skeleton for the home page.
///
/// The header and search bar render no async data, so the real widgets stay
/// visible; every catalogue-driven section below them shimmers with the same
/// paddings, gaps, heights and list behavior as the loaded sections. When the
/// data arrives, real sections replace skeleton sections in place.
class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({super.key, this.physics});

  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
      children: [
        const _HomeSection(child: HomeHeader()),
        SizedBox(height: AppSpacing.lg),
        const _HomeSection(child: HomeSearchBar()),
        SizedBox(height: AppSpacing.lg),
        const BannerSkeleton(),
        SizedBox(height: AppSpacing.lg),
        const _HomeSection(child: HomeCategoriesSkeleton()),
        SizedBox(height: AppSpacing.lg),
        const _HomeSection(child: ProductsCarouselSkeleton()),
        SizedBox(height: AppSpacing.lg),
        _HomeSection(child: ShimmerBannerBox(height: 164, borderRadius: 8)),
        SizedBox(height: AppSpacing.xl),
        const _HomeSection(child: ProductsCarouselSkeleton(showSubtitle: true)),
        SizedBox(height: AppSpacing.lg),
        const _HomeSection(child: BundlesCarouselSkeleton()),
      ],
    );
  }
}

/// Single full-width promo banner skeleton mirroring
/// [HomeSingleBannerSection]: [AppDimensions.homeBannerHeight] tall with radius [AppRadius.r8] and no dots row.
class ShimmerBannerBox extends StatelessWidget {
  const ShimmerBannerBox({
    super.key,
    required this.height,
    required this.borderRadius,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return BannerSkeleton(
      height: height,
      borderRadius: borderRadius,
      showDots: false,
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: child,
    );
  }
}
