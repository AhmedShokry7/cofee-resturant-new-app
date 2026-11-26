import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/features/home/presentation/views/widgets/home_search_bar.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_header.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_section.dart';
import 'package:new_coffee/shared/widgets/shimmer/catalog_skeletons.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// First-load skeleton for the home page.
///
/// The header and search bar render no async data, so the real widgets stay
/// visible; every catalogue-driven section below them shimmers with the same
/// paddings, gaps, heights and list behavior as the loaded sections. When the
/// data arrives, real sections replace skeleton sections in place.
class HomeLoadingView extends StatelessWidget {
  const HomeLoadingView({
    super.key,
    this.physics,
    this.showPersonalBundles = false,
  });

  final ScrollPhysics? physics;
  final bool showPersonalBundles;

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
        // The middle banner may be a single item, so do not reserve room for
        // carousel dots in the loading shape.
        const HomeSection(
          child: BannerSkeleton(borderRadius: AppRadius.r8, showDots: false),
        ),
        SizedBox(height: AppSpacing.xl),
        const HomeSection(child: ProductsCarouselSkeleton(showSubtitle: true)),
        SizedBox(height: AppSpacing.lg),
        const HomeSection(child: BundlesCarouselSkeleton()),
        if (showPersonalBundles) ...[
          SizedBox(height: AppSpacing.lg),
          const HomeSection(child: _PersonalBundlesSkeleton()),
        ],
      ],
    );
  }
}

class _PersonalBundlesSkeleton extends StatelessWidget {
  const _PersonalBundlesSkeleton();

  @override
  Widget build(BuildContext context) => Column(
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
        height: AppSizes.px216,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => Container(
            width: AppSizes.px224,
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: skeletonCardDecoration(context, radius: AppRadius.r16),
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerLine(widthFactor: .72, height: AppSizes.px16),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      for (var image = 0; image < 2; image++) ...[
                        if (image > 0) SizedBox(width: AppSpacing.xs),
                        ShimmerBox(
                          width: AppSizes.px52,
                          height: AppSizes.px52,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  const ShimmerLine(widthFactor: .44, height: AppSizes.px12),
                  const Spacer(),
                  const ShimmerLine(widthFactor: .62, height: AppSizes.px14),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBox(
                    width: double.infinity,
                    height: AppSizes.px40,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
