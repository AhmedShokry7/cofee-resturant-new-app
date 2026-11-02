import 'package:flutter/material.dart';

import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
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
      padding: HomeSection.bodyPadding,
      children: [
        const HomeSection(child: HomeHeader()),
        SizedBox(height: AppSpacing.lg),
        const HomeSection(child: HomeSearchBar()),
        SizedBox(height: AppSpacing.lg),
        const BannerSkeleton(),
        SizedBox(height: AppSpacing.lg),
        const HomeSection(child: HomeCategoriesSkeleton()),
        SizedBox(height: AppSpacing.lg),
        const HomeSection(child: ProductsCarouselSkeleton()),
        SizedBox(height: AppSpacing.lg),
        // The single promo slot: [HomeSingleBannerSection]'s own radius and no
        // dots row. The height comes from the shared default, which is the
        // height that section renders at.
        const HomeSection(
          child: BannerSkeleton(borderRadius: AppRadius.r8, showDots: false),
        ),
        SizedBox(height: AppSpacing.xl),
        const HomeSection(child: ProductsCarouselSkeleton(showSubtitle: true)),
        SizedBox(height: AppSpacing.lg),
        const HomeSection(child: BundlesCarouselSkeleton()),
      ],
    );
  }
}
